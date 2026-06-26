import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

export interface CommandResult {
  success: boolean;
  output?: string;
  error?: string;
}

/**
 * Security Agent — controlled, whitelisted system command execution.
 *
 * All commands are pre-defined and validated. No arbitrary shell execution.
 * In production, the app user needs passwordless sudo for specific commands only.
 *
 * Example sudoers entry:
 *   dashboard ALL=(ALL) NOPASSWD: /usr/bin/fail2ban-client status *
 *   dashboard ALL=(ALL) NOPASSWD: /usr/sbin/ufw status numbered
 *   dashboard ALL=(ALL) NOPASSWD: /usr/bin/tail -n * /var/log/auth.log
 *   dashboard ALL=(ALL) NOPASSWD: /usr/bin/tail -n * /var/log/fail2ban.log
 *   dashboard ALL=(ALL) NOPASSWD: /usr/bin/tail -n * /var/log/ufw.log
 */

async function run(cmd: string): Promise<CommandResult> {
  try {
    const { stdout, stderr } = await execAsync(cmd, {
      timeout: 15000,
      maxBuffer: 5 * 1024 * 1024,
    });
    return { success: true, output: stdout || stderr };
  } catch (err: unknown) {
    const error = err as { message?: string; stdout?: string; stderr?: string };
    return {
      success: false,
      output: error.stdout || "",
      error: error.stderr || error.message || "Command failed",
    };
  }
}

// ─── System Health ────────────────────────────────────────────────────────────

export async function getSystemHealth(): Promise<{
  cpu: number;
  memory: number;
  disk: number;
  loadAverage: string;
  uptime: number;
}> {
  try {
    const [cpuRes, memRes, diskRes, loadRes, uptimeRes] = await Promise.all([
      run("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1 | tr -d ' '"),
      run("free | grep Mem | awk '{printf(\"%.1f\", $3/$2 * 100.0)}'"),
      run("df -h / | tail -1 | awk '{print $5}' | tr -d '%'"),
      run("cat /proc/loadavg | awk '{print $1\", \"$2\", \"$3}'"),
      run("cat /proc/uptime | awk '{print int($1)}'"),
    ]);

    return {
      cpu: parseFloat(cpuRes.output?.trim() || "0"),
      memory: parseFloat(memRes.output?.trim() || "0"),
      disk: parseFloat(diskRes.output?.trim() || "0"),
      loadAverage: loadRes.output?.trim() || "0, 0, 0",
      uptime: parseInt(uptimeRes.output?.trim() || "0"),
    };
  } catch {
    return { cpu: 0, memory: 0, disk: 0, loadAverage: "0, 0, 0", uptime: 0 };
  }
}

// ─── Fail2Ban ─────────────────────────────────────────────────────────────────

export async function getFail2BanStatus(): Promise<CommandResult> {
  return run("sudo fail2ban-client status 2>/dev/null || echo 'fail2ban not running'");
}

export async function getJailStatus(jail: string): Promise<CommandResult> {
  // Sanitize jail name — only allow alphanumeric and hyphens
  const safeJail = jail.replace(/[^a-zA-Z0-9-_]/g, "");
  return run(`sudo fail2ban-client status ${safeJail} 2>/dev/null || echo 'jail not found'`);
}

export async function unbanIP(ip: string, jail: string): Promise<CommandResult> {
  // Validate IP address format
  const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$|^([0-9a-fA-F:]+)$/;
  if (!ipRegex.test(ip)) {
    return { success: false, error: "Invalid IP address format" };
  }
  const safeJail = jail.replace(/[^a-zA-Z0-9-_]/g, "");
  return run(`sudo fail2ban-client set ${safeJail} unbanip ${ip}`);
}

export async function getAllBannedIPs(): Promise<{ jail: string; ips: string[] }[]> {
  const statusRes = await getFail2BanStatus();
  if (!statusRes.success || !statusRes.output) return [];

  // Parse jail list from fail2ban status output
  const jailMatch = statusRes.output.match(/Jail list:\s*(.+)/);
  if (!jailMatch) return [];

  const jails = jailMatch[1].split(",").map((j) => j.trim()).filter(Boolean);
  const results: { jail: string; ips: string[] }[] = [];

  for (const jail of jails) {
    const jailRes = await getJailStatus(jail);
    if (jailRes.success && jailRes.output) {
      const bannedMatch = jailRes.output.match(/Banned IP list:\s*(.+)/);
      const ips = bannedMatch
        ? bannedMatch[1].split(" ").map((ip) => ip.trim()).filter(Boolean)
        : [];
      results.push({ jail, ips });
    }
  }

  return results;
}

// ─── Firewall ─────────────────────────────────────────────────────────────────

export async function getFirewallStatus(): Promise<CommandResult> {
  return run("sudo ufw status numbered 2>/dev/null || echo 'ufw not available'");
}

export async function addFirewallRule(
  action: "allow" | "deny",
  port: string,
  protocol: "tcp" | "udp" | "any"
): Promise<CommandResult> {
  // Validate port — only numbers, ranges, or service names
  const portRegex = /^(\d{1,5}(:\d{1,5})?|[a-zA-Z][a-zA-Z0-9-]*)$/;
  if (!portRegex.test(port)) {
    return { success: false, error: "Invalid port format" };
  }
  const protoStr = protocol === "any" ? "" : `/${protocol}`;
  return run(`sudo ufw ${action} ${port}${protoStr}`);
}

export async function deleteFirewallRule(ruleNumber: number): Promise<CommandResult> {
  if (!Number.isInteger(ruleNumber) || ruleNumber < 1 || ruleNumber > 999) {
    return { success: false, error: "Invalid rule number" };
  }
  return run(`echo y | sudo ufw delete ${ruleNumber}`);
}

// ─── SSH Logs ─────────────────────────────────────────────────────────────────

export async function getSSHAttempts(lines = 100): Promise<CommandResult> {
  const n = Math.min(Math.max(1, lines), 500);
  return run(
    `sudo tail -n ${n} /var/log/auth.log 2>/dev/null | grep -E 'sshd.*(Failed|Accepted|Invalid)' | tail -${n} || echo 'No auth log available'`
  );
}

export async function getTopAttackers(limit = 20): Promise<{ ip: string; count: number }[]> {
  const res = await run(
    `sudo grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{print $11}' | sort | uniq -c | sort -rn | head -${limit}`
  );
  if (!res.success || !res.output) return [];

  return res.output
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const parts = line.trim().split(/\s+/);
      return { count: parseInt(parts[0] || "0"), ip: parts[1] || "" };
    })
    .filter((item) => item.ip);
}

// ─── Log Reading ──────────────────────────────────────────────────────────────

const ALLOWED_LOGS: Record<string, string> = {
  auth: "/var/log/auth.log",
  syslog: "/var/log/syslog",
  fail2ban: "/var/log/fail2ban.log",
  ufw: "/var/log/ufw.log",
  kern: "/var/log/kern.log",
};

export async function getLogLines(
  logName: string,
  lines = 100
): Promise<CommandResult> {
  const logPath = ALLOWED_LOGS[logName];
  if (!logPath) {
    return { success: false, error: `Unknown log: ${logName}. Allowed: ${Object.keys(ALLOWED_LOGS).join(", ")}` };
  }
  const n = Math.min(Math.max(1, lines), 500);
  return run(`sudo tail -n ${n} ${logPath} 2>/dev/null || echo 'Log file not available'`);
}

// ─── Security Verification ────────────────────────────────────────────────────

export async function getSecurityStatus(): Promise<{
  sshRootLogin: string;
  sshPasswordAuth: string;
  ufwActive: boolean;
  fail2banActive: boolean;
  autoUpdatesEnabled: boolean;
}> {
  const [sshRes, ufwRes, f2bRes, autoRes] = await Promise.all([
    run("sudo sshd -T 2>/dev/null | grep -E 'permitrootlogin|passwordauthentication'"),
    run("sudo ufw status 2>/dev/null | head -1"),
    run("sudo systemctl is-active fail2ban 2>/dev/null"),
    run("sudo systemctl is-active unattended-upgrades 2>/dev/null || sudo systemctl is-active apt-daily-upgrade 2>/dev/null"),
  ]);

  const sshOutput = sshRes.output || "";
  const rootLoginMatch = sshOutput.match(/permitrootlogin\s+(\S+)/i);
  const passAuthMatch = sshOutput.match(/passwordauthentication\s+(\S+)/i);

  return {
    sshRootLogin: rootLoginMatch?.[1] || "unknown",
    sshPasswordAuth: passAuthMatch?.[1] || "unknown",
    ufwActive: (ufwRes.output || "").toLowerCase().includes("active"),
    fail2banActive: (f2bRes.output || "").trim() === "active",
    autoUpdatesEnabled: (autoRes.output || "").trim() === "active",
  };
}
