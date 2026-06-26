import { trpc } from "@/lib/trpc";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useLocation } from "wouter";
import {
  Cpu,
  MemoryStick,
  HardDrive,
  Activity,
  Shield,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Clock,
  RefreshCw,
  ChevronRight,
  Ban,
  Flame,
} from "lucide-react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import { format } from "date-fns";

function formatUptime(seconds: number): string {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (d > 0) return `${d}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

function MetricCard({
  title,
  value,
  unit,
  icon: Icon,
  color,
  subtitle,
}: {
  title: string;
  value: number | string;
  unit?: string;
  icon: React.ElementType;
  color: string;
  subtitle?: string;
}) {
  const numVal = typeof value === "number" ? value : 0;
  const isPercentage = unit === "%";
  const barColor =
    isPercentage && numVal > 85
      ? "bg-red-500"
      : isPercentage && numVal > 65
      ? "bg-yellow-500"
      : color;

  return (
    <Card className="bg-card border-border">
      <CardContent className="p-5">
        <div className="flex items-start justify-between mb-3">
          <div>
            <p className="text-xs text-muted-foreground font-medium uppercase tracking-wider">{title}</p>
            <p className="text-2xl font-bold text-foreground mt-0.5">
              {typeof value === "number" ? value.toFixed(1) : value}
              {unit && <span className="text-base font-normal text-muted-foreground ml-1">{unit}</span>}
            </p>
            {subtitle && <p className="text-xs text-muted-foreground mt-0.5">{subtitle}</p>}
          </div>
          <div className={`w-10 h-10 rounded-lg ${color.replace("bg-", "bg-").replace("-500", "-500/15")} flex items-center justify-center`}>
            <Icon className={`w-5 h-5 ${color.replace("bg-", "text-")}`} />
          </div>
        </div>
        {isPercentage && (
          <div className="h-1.5 bg-muted rounded-full overflow-hidden">
            <div
              className={`h-full ${barColor} rounded-full transition-all duration-500`}
              style={{ width: `${Math.min(numVal, 100)}%` }}
            />
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function StatusBadge({ active, label }: { active: boolean; label: string }) {
  return (
    <div className="flex items-center justify-between py-2.5 border-b border-border last:border-0">
      <span className="text-sm text-foreground">{label}</span>
      {active ? (
        <Badge className="bg-green-500/15 text-green-400 border-green-500/30 text-xs">
          <CheckCircle className="w-3 h-3 mr-1" /> Active
        </Badge>
      ) : (
        <Badge className="bg-red-500/15 text-red-400 border-red-500/30 text-xs">
          <XCircle className="w-3 h-3 mr-1" /> Inactive
        </Badge>
      )}
    </div>
  );
}

export default function Overview() {
  const [, navigate] = useLocation();

  const { data: health, isLoading: healthLoading, refetch: refetchHealth } = trpc.health.current.useQuery(undefined, {
    refetchInterval: 30000,
  });

  const { data: alertCounts } = trpc.alerts.counts.useQuery(undefined, {
    refetchInterval: 30000,
  });

  const { data: secStatus } = trpc.health.securityStatus.useQuery(undefined, {
    refetchInterval: 60000,
  });

  const { data: healthHistory } = trpc.health.history.useQuery(
    { hours: 6 },
    { refetchInterval: 60000 }
  );

  const chartData = (healthHistory ?? [])
    .slice()
    .reverse()
    .slice(-24)
    .map((h) => ({
      time: format(new Date(h.createdAt), "HH:mm"),
      cpu: h.cpuUsage ?? 0,
      mem: h.memoryUsage ?? 0,
      disk: h.diskUsage ?? 0,
    }));

  return (
    <div className="space-y-6">
      {/* Page header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Overview</h1>
          <p className="text-muted-foreground text-sm mt-0.5">System health and security status at a glance</p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => refetchHealth()}
          className="gap-2"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          Refresh
        </Button>
      </div>

      {/* Alert summary banner */}
      {alertCounts && alertCounts.total > 0 && (
        <div
          className="flex items-center justify-between bg-red-500/10 border border-red-500/30 rounded-xl px-5 py-3 cursor-pointer hover:bg-red-500/15 transition-colors"
          onClick={() => navigate("/alerts")}
        >
          <div className="flex items-center gap-3">
            <AlertTriangle className="w-5 h-5 text-red-400" />
            <div>
              <p className="text-sm font-semibold text-red-400">
                {alertCounts.total} unacknowledged alert{alertCounts.total !== 1 ? "s" : ""}
              </p>
              <p className="text-xs text-red-400/70">
                {alertCounts.critical > 0 && `${alertCounts.critical} critical`}
                {alertCounts.critical > 0 && alertCounts.high > 0 && " · "}
                {alertCounts.high > 0 && `${alertCounts.high} high`}
              </p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-red-400" />
        </div>
      )}

      {/* System metrics */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricCard
          title="CPU Usage"
          value={health?.cpu ?? 0}
          unit="%"
          icon={Cpu}
          color="bg-blue-500"
          subtitle={`Load: ${health?.loadAverage ?? "—"}`}
        />
        <MetricCard
          title="Memory"
          value={health?.memory ?? 0}
          unit="%"
          icon={MemoryStick}
          color="bg-purple-500"
        />
        <MetricCard
          title="Disk Usage"
          value={health?.disk ?? 0}
          unit="%"
          icon={HardDrive}
          color="bg-cyan-500"
        />
        <MetricCard
          title="Uptime"
          value={formatUptime(health?.uptime ?? 0)}
          icon={Clock}
          color="bg-green-500"
        />
      </div>

      {/* Charts + Security status */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Resource history chart */}
        <Card className="lg:col-span-2 bg-card border-border">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
              <Activity className="w-4 h-4 text-primary" />
              Resource History (6h)
            </CardTitle>
          </CardHeader>
          <CardContent>
            {chartData.length > 0 ? (
              <ResponsiveContainer width="100%" height={180}>
                <AreaChart data={chartData} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="cpuGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#38bdf8" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#38bdf8" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="memGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#a78bfa" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#a78bfa" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="time" tick={{ fontSize: 10, fill: "#64748b" }} tickLine={false} axisLine={false} />
                  <YAxis tick={{ fontSize: 10, fill: "#64748b" }} tickLine={false} axisLine={false} domain={[0, 100]} />
                  <Tooltip
                    contentStyle={{ background: "#1e293b", border: "1px solid #334155", borderRadius: "8px", fontSize: "12px" }}
                    labelStyle={{ color: "#94a3b8" }}
                  />
                  <Area type="monotone" dataKey="cpu" stroke="#38bdf8" strokeWidth={1.5} fill="url(#cpuGrad)" name="CPU %" />
                  <Area type="monotone" dataKey="mem" stroke="#a78bfa" strokeWidth={1.5} fill="url(#memGrad)" name="Mem %" />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-[180px] flex items-center justify-center text-muted-foreground text-sm">
                {healthLoading ? "Loading..." : "No history data yet. Refresh to collect data."}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Security status */}
        <Card className="bg-card border-border">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
              <Shield className="w-4 h-4 text-primary" />
              Security Status
            </CardTitle>
          </CardHeader>
          <CardContent>
            {secStatus ? (
              <div>
                <StatusBadge active={secStatus.ufwActive} label="UFW Firewall" />
                <StatusBadge active={secStatus.fail2banActive} label="Fail2Ban" />
                <StatusBadge active={secStatus.autoUpdatesEnabled} label="Auto Updates" />
                <StatusBadge active={secStatus.sshRootLogin === "no"} label="Root Login Disabled" />
                <StatusBadge active={secStatus.sshPasswordAuth === "no"} label="Password Auth Disabled" />
              </div>
            ) : (
              <div className="text-muted-foreground text-sm py-4 text-center">Loading...</div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Quick action cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {[
          { label: "Manage Alerts", desc: `${alertCounts?.total ?? 0} pending`, icon: AlertTriangle, path: "/alerts", color: "text-red-400" },
          { label: "Fail2Ban", desc: "View bans & jails", icon: Ban, path: "/fail2ban", color: "text-orange-400" },
          { label: "Firewall Rules", desc: "UFW management", icon: Flame, path: "/firewall", color: "text-yellow-400" },
        ].map(({ label, desc, icon: Icon, path, color }) => (
          <button
            key={path}
            onClick={() => navigate(path)}
            className="bg-card border border-border rounded-xl p-4 text-left hover:border-primary/40 hover:bg-accent/30 transition-all active:scale-[0.98] group"
          >
            <Icon className={`w-5 h-5 ${color} mb-2`} />
            <p className="text-sm font-semibold text-foreground">{label}</p>
            <p className="text-xs text-muted-foreground mt-0.5">{desc}</p>
            <ChevronRight className="w-4 h-4 text-muted-foreground mt-2 group-hover:translate-x-1 transition-transform" />
          </button>
        ))}
      </div>
    </div>
  );
}
