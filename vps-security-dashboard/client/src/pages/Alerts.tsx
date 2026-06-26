import { trpc } from "@/lib/trpc";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import { AlertTriangle, CheckCheck, RefreshCw, Bell } from "lucide-react";
import { format } from "date-fns";

const severityClass: Record<string, string> = {
  critical: "severity-critical",
  high: "severity-high",
  medium: "severity-medium",
  low: "severity-low",
};

export default function Alerts() {
  const utils = trpc.useUtils();

  const { data: alerts, isLoading, refetch } = trpc.alerts.list.useQuery({
    limit: 100,
    onlyUnacknowledged: false,
  });

  const { data: counts } = trpc.alerts.counts.useQuery();

  const acknowledge = trpc.alerts.acknowledge.useMutation({
    onSuccess: () => {
      utils.alerts.list.invalidate();
      utils.alerts.counts.invalidate();
      toast.success("Alert acknowledged");
    },
  });

  const acknowledgeAll = trpc.alerts.acknowledgeAll.useMutation({
    onSuccess: (data) => {
      utils.alerts.list.invalidate();
      utils.alerts.counts.invalidate();
      toast.success(`${data.count} alerts acknowledged`);
    },
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Security Alerts</h1>
          <p className="text-muted-foreground text-sm mt-0.5">
            {counts?.total ?? 0} unacknowledged · {alerts?.length ?? 0} total
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2">
            <RefreshCw className="w-3.5 h-3.5" /> Refresh
          </Button>
          {(counts?.total ?? 0) > 0 && (
            <Button
              size="sm"
              onClick={() => acknowledgeAll.mutate()}
              disabled={acknowledgeAll.isPending}
              className="gap-2 bg-primary text-primary-foreground hover:bg-primary/90"
            >
              <CheckCheck className="w-3.5 h-3.5" /> Acknowledge All
            </Button>
          )}
        </div>
      </div>

      {/* Severity summary */}
      <div className="grid grid-cols-4 gap-3">
        {(["critical", "high", "medium", "low"] as const).map((sev) => (
          <Card key={sev} className="bg-card border-border">
            <CardContent className="p-4 text-center">
              <p className="text-2xl font-bold text-foreground">{counts?.[sev] ?? 0}</p>
              <Badge className={`${severityClass[sev]} mt-1 text-xs capitalize`}>{sev}</Badge>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Alert list */}
      <Card className="bg-card border-border">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
            <Bell className="w-4 h-4 text-primary" />
            All Alerts
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="py-12 text-center text-muted-foreground text-sm">Loading alerts...</div>
          ) : !alerts || alerts.length === 0 ? (
            <div className="py-12 text-center">
              <AlertTriangle className="w-8 h-8 text-muted-foreground mx-auto mb-3" />
              <p className="text-muted-foreground text-sm">No alerts found</p>
            </div>
          ) : (
            <div className="divide-y divide-border">
              {alerts.map((alert) => (
                <div
                  key={alert.id}
                  className={`flex items-start justify-between px-5 py-4 hover:bg-accent/20 transition-colors ${alert.acknowledged ? "opacity-50" : ""}`}
                >
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <Badge className={`${severityClass[alert.severity]} text-xs capitalize`}>
                        {alert.severity}
                      </Badge>
                      <span className="text-xs text-muted-foreground">{alert.alertType}</span>
                      {alert.sourceIp && (
                        <span className="text-xs font-mono text-muted-foreground bg-muted/50 px-1.5 py-0.5 rounded">
                          {alert.sourceIp}
                        </span>
                      )}
                    </div>
                    <p className="text-sm font-medium text-foreground">{alert.title}</p>
                    {alert.description && (
                      <p className="text-xs text-muted-foreground mt-0.5 truncate">{alert.description}</p>
                    )}
                    <p className="text-xs text-muted-foreground mt-1">
                      {format(new Date(alert.createdAt), "MMM d, yyyy HH:mm:ss")}
                      {alert.count && alert.count > 1 && (
                        <span className="ml-2 text-primary">×{alert.count}</span>
                      )}
                    </p>
                  </div>
                  {!alert.acknowledged && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => acknowledge.mutate({ id: alert.id })}
                      disabled={acknowledge.isPending}
                      className="ml-4 shrink-0 text-xs"
                    >
                      Dismiss
                    </Button>
                  )}
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
