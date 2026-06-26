import { trpc } from "@/lib/trpc";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ScrollText, RefreshCw, UserX } from "lucide-react";
import { useState } from "react";

type LogName = "auth" | "syslog" | "fail2ban" | "ufw" | "kern";

const LOG_OPTIONS: { value: LogName; label: string }[] = [
  { value: "auth", label: "Auth Log (/var/log/auth.log)" },
  { value: "fail2ban", label: "Fail2Ban (/var/log/fail2ban.log)" },
  { value: "ufw", label: "UFW (/var/log/ufw.log)" },
  { value: "syslog", label: "Syslog (/var/log/syslog)" },
  { value: "kern", label: "Kernel (/var/log/kern.log)" },
];

function colorizeLog(line: string): string {
  if (line.includes("Failed") || line.includes("BLOCK") || line.includes("Ban ")) return "text-red-400";
  if (line.includes("Accepted") || line.includes("Unban")) return "text-green-400";
  if (line.includes("Invalid") || line.includes("error") || line.includes("WARN")) return "text-yellow-400";
  if (line.includes("sshd") || line.includes("UFW")) return "text-blue-400";
  return "text-foreground/80";
}

export default function Logs() {
  const [logName, setLogName] = useState<LogName>("auth");
  const [lines, setLines] = useState(100);

  const { data: logData, isLoading, refetch } = trpc.logs.raw.useQuery(
    { logName, lines },
    { refetchOnWindowFocus: false }
  );

  const { data: topAttackers } = trpc.logs.topAttackers.useQuery(
    { limit: 15 },
    { refetchOnWindowFocus: false }
  );

  const logLines = (logData?.output || "").split("\n").filter(Boolean);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Log Viewer</h1>
          <p className="text-muted-foreground text-sm mt-0.5">Browse system security logs</p>
        </div>
        <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2">
          <RefreshCw className="w-3.5 h-3.5" /> Refresh
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Log viewer */}
        <div className="lg:col-span-2 space-y-4">
          <div className="flex gap-3">
            <Select value={logName} onValueChange={(v) => setLogName(v as LogName)}>
              <SelectTrigger className="flex-1 h-9 text-sm bg-input border-border">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {LOG_OPTIONS.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Select value={String(lines)} onValueChange={(v) => setLines(Number(v))}>
              <SelectTrigger className="w-28 h-9 text-sm bg-input border-border">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {[50, 100, 200, 500].map((n) => (
                  <SelectItem key={n} value={String(n)}>{n} lines</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <Card className="bg-card border-border">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
                <ScrollText className="w-4 h-4 text-primary" />
                {LOG_OPTIONS.find((o) => o.value === logName)?.label}
                <Badge variant="outline" className="text-xs ml-auto">{logLines.length} lines</Badge>
              </CardTitle>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <div className="py-8 text-center text-muted-foreground text-sm">Loading...</div>
              ) : logData?.error ? (
                <div className="py-8 text-center text-red-400 text-sm">{logData.error}</div>
              ) : (
                <div className="bg-muted/30 rounded-lg p-4 overflow-auto max-h-[500px]">
                  {logLines.length === 0 ? (
                    <p className="text-muted-foreground text-xs">No log entries found</p>
                  ) : (
                    logLines.map((line, i) => (
                      <div key={i} className={`log-output ${colorizeLog(line)} hover:bg-white/5 px-1 rounded`}>
                        {line}
                      </div>
                    ))
                  )}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Top attackers */}
        <div>
          <Card className="bg-card border-border">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
                <UserX className="w-4 h-4 text-red-400" />
                Top Attackers
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              {!topAttackers || topAttackers.length === 0 ? (
                <div className="py-8 text-center text-muted-foreground text-sm px-4">
                  No failed login attempts found
                </div>
              ) : (
                <div className="divide-y divide-border">
                  {topAttackers.map((attacker, i) => (
                    <div key={attacker.ip} className="flex items-center justify-between px-4 py-2.5 hover:bg-accent/20 transition-colors">
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-muted-foreground w-5 text-right">{i + 1}.</span>
                        <code className="text-xs font-mono text-foreground">{attacker.ip}</code>
                      </div>
                      <Badge className="severity-high text-xs">{attacker.count}x</Badge>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
