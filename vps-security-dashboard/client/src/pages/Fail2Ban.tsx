import { trpc } from "@/lib/trpc";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import { Shield, Ban, RefreshCw, Unlock, Clock } from "lucide-react";
import { format } from "date-fns";

export default function Fail2Ban() {
  const utils = trpc.useUtils();

  const { data: status, isLoading: statusLoading, refetch: refetchStatus } = trpc.fail2ban.status.useQuery();
  const { data: bannedIPs, isLoading: bansLoading, refetch: refetchBans } = trpc.fail2ban.bannedIPs.useQuery();
  const { data: history, isLoading: histLoading } = trpc.fail2ban.history.useQuery({ limit: 50 });

  const unbanIP = trpc.fail2ban.unbanIP.useMutation({
    onSuccess: (result, vars) => {
      if (result.success) {
        toast.success(`IP ${vars.ip} unbanned from ${vars.jail}`);
        utils.fail2ban.bannedIPs.invalidate();
        utils.fail2ban.history.invalidate();
      } else {
        toast.error(`Failed to unban: ${result.error}`);
      }
    },
  });

  const totalBanned = bannedIPs?.reduce((sum, j) => sum + j.ips.length, 0) ?? 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Fail2Ban</h1>
          <p className="text-muted-foreground text-sm mt-0.5">
            {totalBanned} IP{totalBanned !== 1 ? "s" : ""} currently banned
          </p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => { refetchStatus(); refetchBans(); }}
          className="gap-2"
        >
          <RefreshCw className="w-3.5 h-3.5" /> Refresh
        </Button>
      </div>

      {/* Status output */}
      <Card className="bg-card border-border">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
            <Shield className="w-4 h-4 text-primary" />
            Service Status
          </CardTitle>
        </CardHeader>
        <CardContent>
          {statusLoading ? (
            <p className="text-muted-foreground text-sm">Loading...</p>
          ) : (
            <pre className="log-output text-foreground bg-muted/30 rounded-lg p-4 overflow-x-auto whitespace-pre-wrap text-xs">
              {status?.output || status?.error || "No output"}
            </pre>
          )}
        </CardContent>
      </Card>

      {/* Currently banned IPs */}
      <Card className="bg-card border-border">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
            <Ban className="w-4 h-4 text-red-400" />
            Currently Banned IPs
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {bansLoading ? (
            <div className="py-8 text-center text-muted-foreground text-sm">Loading...</div>
          ) : !bannedIPs || bannedIPs.length === 0 || totalBanned === 0 ? (
            <div className="py-8 text-center">
              <Shield className="w-8 h-8 text-green-400 mx-auto mb-2" />
              <p className="text-muted-foreground text-sm">No IPs currently banned</p>
            </div>
          ) : (
            <div className="divide-y divide-border">
              {bannedIPs.map(({ jail, ips }) =>
                ips.map((ip) => (
                  <div key={`${jail}-${ip}`} className="flex items-center justify-between px-5 py-3 hover:bg-accent/20 transition-colors">
                    <div className="flex items-center gap-3">
                      <Badge className="severity-high text-xs">{jail}</Badge>
                      <code className="text-sm font-mono text-foreground">{ip}</code>
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => unbanIP.mutate({ ip, jail })}
                      disabled={unbanIP.isPending}
                      className="gap-1.5 text-xs text-green-400 border-green-500/30 hover:bg-green-500/10"
                    >
                      <Unlock className="w-3 h-3" /> Unban
                    </Button>
                  </div>
                ))
              )}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Ban history */}
      <Card className="bg-card border-border">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
            <Clock className="w-4 h-4 text-muted-foreground" />
            Ban History
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {histLoading ? (
            <div className="py-8 text-center text-muted-foreground text-sm">Loading...</div>
          ) : !history || history.length === 0 ? (
            <div className="py-8 text-center text-muted-foreground text-sm">No history recorded yet</div>
          ) : (
            <div className="divide-y divide-border">
              {history.map((entry) => (
                <div key={entry.id} className="flex items-center justify-between px-5 py-3 hover:bg-accent/20 transition-colors">
                  <div>
                    <div className="flex items-center gap-2 mb-0.5">
                      <code className="text-sm font-mono text-foreground">{entry.ipAddress}</code>
                      <Badge className="severity-medium text-xs">{entry.jail}</Badge>
                    </div>
                    <p className="text-xs text-muted-foreground">
                      Banned: {format(new Date(entry.bannedAt), "MMM d, HH:mm")}
                      {entry.unbannedAt && ` · Unbanned: ${format(new Date(entry.unbannedAt), "MMM d, HH:mm")}`}
                    </p>
                    {entry.reason && <p className="text-xs text-muted-foreground mt-0.5">{entry.reason}</p>}
                  </div>
                  <Badge className={entry.unbannedAt ? "bg-green-500/15 text-green-400 border-green-500/30 text-xs" : "severity-high text-xs"}>
                    {entry.unbannedAt ? "Unbanned" : "Active"}
                  </Badge>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
