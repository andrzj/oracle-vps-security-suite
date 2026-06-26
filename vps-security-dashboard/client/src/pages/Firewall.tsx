import { trpc } from "@/lib/trpc";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { Flame, Plus, Trash2, RefreshCw, ShieldCheck } from "lucide-react";
import { useState } from "react";
import { format } from "date-fns";

export default function Firewall() {
  const utils = trpc.useUtils();

  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    action: "allow" as "allow" | "deny",
    port: "",
    protocol: "tcp" as "tcp" | "udp" | "any",
    direction: "in" as "in" | "out",
    description: "",
  });

  const { data: status, isLoading: statusLoading, refetch } = trpc.firewall.status.useQuery();
  const { data: rules, isLoading: rulesLoading } = trpc.firewall.rules.useQuery();

  const addRule = trpc.firewall.addRule.useMutation({
    onSuccess: (result) => {
      if (result.success) {
        toast.success("Firewall rule added");
        utils.firewall.status.invalidate();
        utils.firewall.rules.invalidate();
        setShowForm(false);
        setFormData({ action: "allow", port: "", protocol: "tcp", direction: "in", description: "" });
      } else {
        toast.error(`Failed: ${result.error}`);
      }
    },
  });

  const deleteRule = trpc.firewall.deleteRule.useMutation({
    onSuccess: (result, vars) => {
      if (result.success) {
        toast.success("Rule deleted");
        utils.firewall.status.invalidate();
        utils.firewall.rules.invalidate();
      } else {
        toast.error(`Failed: ${result.error}`);
      }
    },
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Firewall</h1>
          <p className="text-muted-foreground text-sm mt-0.5">UFW rule management</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-2">
            <RefreshCw className="w-3.5 h-3.5" /> Refresh
          </Button>
          <Button
            size="sm"
            onClick={() => setShowForm(!showForm)}
            className="gap-2 bg-primary text-primary-foreground hover:bg-primary/90"
          >
            <Plus className="w-3.5 h-3.5" /> Add Rule
          </Button>
        </div>
      </div>

      {/* Add rule form */}
      {showForm && (
        <Card className="bg-card border-primary/30">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-semibold text-foreground">New Firewall Rule</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-4">
              <div>
                <Label className="text-xs text-muted-foreground mb-1.5 block">Action</Label>
                <Select value={formData.action} onValueChange={(v) => setFormData((p) => ({ ...p, action: v as "allow" | "deny" }))}>
                  <SelectTrigger className="h-9 text-sm bg-input border-border">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="allow">Allow</SelectItem>
                    <SelectItem value="deny">Deny</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label className="text-xs text-muted-foreground mb-1.5 block">Port</Label>
                <Input
                  placeholder="e.g. 443"
                  value={formData.port}
                  onChange={(e) => setFormData((p) => ({ ...p, port: e.target.value }))}
                  className="h-9 text-sm bg-input border-border"
                />
              </div>
              <div>
                <Label className="text-xs text-muted-foreground mb-1.5 block">Protocol</Label>
                <Select value={formData.protocol} onValueChange={(v) => setFormData((p) => ({ ...p, protocol: v as "tcp" | "udp" | "any" }))}>
                  <SelectTrigger className="h-9 text-sm bg-input border-border">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="tcp">TCP</SelectItem>
                    <SelectItem value="udp">UDP</SelectItem>
                    <SelectItem value="any">Any</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label className="text-xs text-muted-foreground mb-1.5 block">Direction</Label>
                <Select value={formData.direction} onValueChange={(v) => setFormData((p) => ({ ...p, direction: v as "in" | "out" }))}>
                  <SelectTrigger className="h-9 text-sm bg-input border-border">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="in">Inbound</SelectItem>
                    <SelectItem value="out">Outbound</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="mb-4">
              <Label className="text-xs text-muted-foreground mb-1.5 block">Description (optional)</Label>
              <Input
                placeholder="e.g. HTTPS traffic"
                value={formData.description}
                onChange={(e) => setFormData((p) => ({ ...p, description: e.target.value }))}
                className="h-9 text-sm bg-input border-border"
              />
            </div>
            <div className="flex gap-2">
              <Button
                size="sm"
                onClick={() => addRule.mutate(formData)}
                disabled={!formData.port || addRule.isPending}
                className="bg-primary text-primary-foreground hover:bg-primary/90"
              >
                {addRule.isPending ? "Adding..." : "Add Rule"}
              </Button>
              <Button variant="outline" size="sm" onClick={() => setShowForm(false)}>
                Cancel
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* UFW status output */}
      <Card className="bg-card border-border">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
            <ShieldCheck className="w-4 h-4 text-primary" />
            UFW Status
          </CardTitle>
        </CardHeader>
        <CardContent>
          {statusLoading ? (
            <p className="text-muted-foreground text-sm">Loading...</p>
          ) : (
            <pre className="log-output text-foreground bg-muted/30 rounded-lg p-4 overflow-x-auto whitespace-pre-wrap text-xs">
              {status?.output || status?.error || "UFW not available"}
            </pre>
          )}
        </CardContent>
      </Card>

      {/* Dashboard-tracked rules */}
      <Card className="bg-card border-border">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold text-foreground flex items-center gap-2">
            <Flame className="w-4 h-4 text-orange-400" />
            Dashboard-Managed Rules
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {rulesLoading ? (
            <div className="py-8 text-center text-muted-foreground text-sm">Loading...</div>
          ) : !rules || rules.length === 0 ? (
            <div className="py-8 text-center text-muted-foreground text-sm">
              No rules added via dashboard yet
            </div>
          ) : (
            <div className="divide-y divide-border">
              {rules.map((rule, idx) => (
                <div key={rule.id} className="flex items-center justify-between px-5 py-3 hover:bg-accent/20 transition-colors">
                  <div className="flex items-center gap-3">
                    <Badge className={rule.action === "allow" ? "bg-green-500/15 text-green-400 border-green-500/30 text-xs" : "severity-high text-xs"}>
                      {rule.action}
                    </Badge>
                    <code className="text-sm font-mono text-foreground">{rule.port}/{rule.protocol}</code>
                    <Badge variant="outline" className="text-xs text-muted-foreground">{rule.direction}</Badge>
                    {rule.description && <span className="text-xs text-muted-foreground">{rule.description}</span>}
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-muted-foreground">
                      {format(new Date(rule.createdAt), "MMM d")}
                    </span>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => deleteRule.mutate({ ruleNumber: idx + 1, dbId: rule.id })}
                      disabled={deleteRule.isPending}
                      className="gap-1 text-xs text-red-400 border-red-500/30 hover:bg-red-500/10"
                    >
                      <Trash2 className="w-3 h-3" />
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
