import { trpc } from "@/lib/trpc";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ClipboardList, RefreshCw, ChevronLeft, ChevronRight } from "lucide-react";
import { useState } from "react";
import { format } from "date-fns";

const actionColor: Record<string, string> = {
  unban_ip: "bg-green-500/15 text-green-400 border-green-500/30",
  add_firewall_rule: "bg-blue-500/15 text-blue-400 border-blue-500/30",
  delete_firewall_rule: "bg-red-500/15 text-red-400 border-red-500/30",
  acknowledge_alert: "bg-purple-500/15 text-purple-400 border-purple-500/30",
  acknowledge_all_alerts: "bg-purple-500/15 text-purple-400 border-purple-500/30",
  view_ssh_logs: "bg-muted text-muted-foreground",
  view_log: "bg-muted text-muted-foreground",
  view_top_attackers: "bg-muted text-muted-foreground",
  get_fail2ban_status: "bg-muted text-muted-foreground",
  get_banned_ips: "bg-muted text-muted-foreground",
  get_firewall_status: "bg-muted text-muted-foreground",
};

const PAGE_SIZE = 50;

export default function AuditLog() {
  const [page, setPage] = useState(0);

  const { data, isLoading, refetch } = trpc.audit.list.useQuery(
    { limit: PAGE_SIZE, offset: page * PAGE_SIZE },
    { refetchOnWindowFocus: false }
  );

  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Audit Log</h1>
          <p className="text-muted-foreground text-sm mt-0.5">
            {data?.total ?? 0} total actions recorded
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2">
          <RefreshCw className="w-3.5 h-3.5" /> Refresh
        </Button>
      </div>

      <Card className="bg-card border-border">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
            <ClipboardList className="w-4 h-4 text-primary" />
            Action History
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="py-12 text-center text-muted-foreground text-sm">Loading...</div>
          ) : !data || data.logs.length === 0 ? (
            <div className="py-12 text-center text-muted-foreground text-sm">No audit entries yet</div>
          ) : (
            <>
              <div className="divide-y divide-border">
                {data.logs.map((entry) => (
                  <div key={entry.id} className="flex items-start justify-between px-5 py-3.5 hover:bg-accent/20 transition-colors">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1 flex-wrap">
                        <Badge className={`${actionColor[entry.action] ?? "bg-muted text-muted-foreground"} text-xs`}>
                          {entry.action.replace(/_/g, " ")}
                        </Badge>
                        <span className="text-xs text-muted-foreground">{entry.resource}</span>
                        {entry.resourceId && (
                          <code className="text-xs font-mono text-muted-foreground bg-muted/50 px-1.5 py-0.5 rounded">
                            {entry.resourceId}
                          </code>
                        )}
                      </div>
                      {entry.details && (
                        <p className="text-xs text-muted-foreground truncate">{entry.details}</p>
                      )}
                      <p className="text-xs text-muted-foreground mt-0.5">
                        {format(new Date(entry.createdAt), "MMM d, yyyy HH:mm:ss")}
                        {entry.adminId && <span className="ml-2">· Admin #{entry.adminId}</span>}
                      </p>
                    </div>
                    <Badge
                      className={
                        entry.status === "success"
                          ? "bg-green-500/15 text-green-400 border-green-500/30 text-xs shrink-0 ml-3"
                          : "severity-high text-xs shrink-0 ml-3"
                      }
                    >
                      {entry.status}
                    </Badge>
                  </div>
                ))}
              </div>

              {/* Pagination */}
              {totalPages > 1 && (
                <div className="flex items-center justify-between px-5 py-3 border-t border-border">
                  <span className="text-xs text-muted-foreground">
                    Page {page + 1} of {totalPages}
                  </span>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setPage((p) => Math.max(0, p - 1))}
                      disabled={page === 0}
                      className="gap-1"
                    >
                      <ChevronLeft className="w-3.5 h-3.5" /> Prev
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
                      disabled={page >= totalPages - 1}
                      className="gap-1"
                    >
                      Next <ChevronRight className="w-3.5 h-3.5" />
                    </Button>
                  </div>
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
