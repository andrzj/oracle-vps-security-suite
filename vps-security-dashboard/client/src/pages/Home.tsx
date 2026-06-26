import { useAuth } from "@/_core/hooks/useAuth";
import { getLoginUrl } from "@/const";
import { Button } from "@/components/ui/button";
import { useEffect } from "react";
import { useLocation } from "wouter";
import { Shield, Lock, Activity, Eye, Server, AlertTriangle } from "lucide-react";

export default function Home() {
  const { isAuthenticated, loading } = useAuth();
  const [, navigate] = useLocation();

  useEffect(() => {
    if (!loading && isAuthenticated) {
      navigate("/dashboard");
    }
  }, [isAuthenticated, loading, navigate]);

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 rounded-full border-2 border-primary border-t-transparent animate-spin" />
          <p className="text-muted-foreground text-sm">Loading...</p>
        </div>
      </div>
    );
  }

  const features = [
    { icon: Activity, title: "System Health", desc: "Real-time CPU, memory, disk, and load monitoring" },
    { icon: AlertTriangle, title: "Security Alerts", desc: "Instant visibility into threats and anomalies" },
    { icon: Shield, title: "Fail2Ban Control", desc: "View jails, banned IPs, and unban with one click" },
    { icon: Lock, title: "Firewall Manager", desc: "Inspect and manage UFW rules from the browser" },
    { icon: Eye, title: "Log Viewer", desc: "Browse auth, syslog, UFW, and Fail2Ban logs" },
    { icon: Server, title: "Audit Trail", desc: "Every dashboard action is logged and timestamped" },
  ];

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      <header className="border-b border-border px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-primary/20 flex items-center justify-center">
            <Shield className="w-5 h-5 text-primary" />
          </div>
          <span className="font-semibold text-foreground tracking-tight">VPS Security Dashboard</span>
        </div>
        <Button
          onClick={() => (window.location.href = getLoginUrl())}
          className="bg-primary text-primary-foreground hover:bg-primary/90 transition-all active:scale-[0.97]"
          size="sm"
        >
          Sign In
        </Button>
      </header>

      {/* Hero */}
      <main className="flex-1 flex flex-col items-center justify-center px-6 py-20 text-center">
        <div className="max-w-3xl mx-auto">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-primary/10 border border-primary/20 text-primary text-xs font-medium mb-8">
            <span className="w-1.5 h-1.5 rounded-full bg-primary status-dot-active" />
            Oracle Cloud Free Tier — Security Suite
          </div>

          <h1 className="text-4xl sm:text-5xl font-bold text-foreground mb-6 leading-tight tracking-tight">
            Secure your VPS.
            <br />
            <span className="text-primary">Monitor everything.</span>
          </h1>

          <p className="text-muted-foreground text-lg mb-10 max-w-xl mx-auto leading-relaxed">
            A self-hosted security dashboard for your Oracle Cloud VPS. Monitor system health,
            manage Fail2Ban, control UFW firewall rules, and browse security logs — all from a
            single authenticated interface.
          </p>

          <Button
            onClick={() => (window.location.href = getLoginUrl())}
            size="lg"
            className="bg-primary text-primary-foreground hover:bg-primary/90 px-8 transition-all active:scale-[0.97]"
          >
            <Shield className="w-4 h-4 mr-2" />
            Open Dashboard
          </Button>
        </div>

        {/* Feature grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-20 max-w-4xl w-full">
          {features.map(({ icon: Icon, title, desc }) => (
            <div
              key={title}
              className="bg-card border border-border rounded-xl p-5 text-left hover:border-primary/40 transition-colors"
            >
              <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center mb-3">
                <Icon className="w-5 h-5 text-primary" />
              </div>
              <h3 className="font-semibold text-foreground text-sm mb-1">{title}</h3>
              <p className="text-muted-foreground text-xs leading-relaxed">{desc}</p>
            </div>
          ))}
        </div>
      </main>

      <footer className="border-t border-border px-6 py-4 text-center text-xs text-muted-foreground">
        Secured with Manus OAuth · All actions are audit-logged · Access restricted to authenticated users
      </footer>
    </div>
  );
}
