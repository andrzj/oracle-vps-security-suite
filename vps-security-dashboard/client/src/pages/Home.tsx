import { useAuth } from "@/_core/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { trpc } from "@/lib/trpc";
import { AlertTriangle, Eye, EyeOff, Lock, Shield } from "lucide-react";
import { useEffect, useState } from "react";
import { useLocation } from "wouter";

export default function Home() {
  const { isAuthenticated, loading } = useAuth();
  const [, navigate] = useLocation();

  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [errorMsg, setErrorMsg] = useState("");
  const [isSetupMode, setIsSetupMode] = useState(false);
  const [confirmPassword, setConfirmPassword] = useState("");

  // Check if first-run setup is needed
  const setupStatusQuery = trpc.auth.setupStatus.useQuery(undefined, {
    retry: false,
  });

  useEffect(() => {
    if (setupStatusQuery.data?.needsSetup) {
      setIsSetupMode(true);
    }
  }, [setupStatusQuery.data]);

  // Redirect to dashboard if already authenticated
  useEffect(() => {
    if (!loading && isAuthenticated) {
      navigate("/dashboard");
    }
  }, [isAuthenticated, loading, navigate]);

  const loginMutation = trpc.auth.login.useMutation({
    onSuccess: () => {
      navigate("/dashboard");
    },
    onError: (err) => {
      setErrorMsg(err.message || "Invalid username or password.");
    },
  });

  const setupMutation = trpc.auth.setup.useMutation({
    onSuccess: () => {
      navigate("/dashboard");
    },
    onError: (err) => {
      setErrorMsg(err.message || "Setup failed. Please try again.");
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg("");

    if (!username.trim() || !password.trim()) {
      setErrorMsg("Username and password are required.");
      return;
    }

    if (isSetupMode) {
      if (password !== confirmPassword) {
        setErrorMsg("Passwords do not match.");
        return;
      }
      if (password.length < 12) {
        setErrorMsg("Password must be at least 12 characters.");
        return;
      }
      setupMutation.mutate({ username: username.trim(), password });
    } else {
      loginMutation.mutate({ username: username.trim(), password });
    }
  };

  if (loading || setupStatusQuery.isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 rounded-full border-2 border-primary border-t-transparent animate-spin" />
          <p className="text-muted-foreground text-sm">Loading...</p>
        </div>
      </div>
    );
  }

  const isPending = loginMutation.isPending || setupMutation.isPending;

  return (
    <div className="min-h-screen bg-background flex flex-col items-center justify-center px-4">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex flex-col items-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-primary/15 border border-primary/30 flex items-center justify-center mb-4">
            <Shield className="w-7 h-7 text-primary" />
          </div>
          <h1 className="text-xl font-bold text-foreground tracking-tight">VPS Security Dashboard</h1>
          <p className="text-muted-foreground text-sm mt-1">
            {isSetupMode ? "Create your admin account to get started" : "Sign in to your dashboard"}
          </p>
        </div>

        {/* Setup banner */}
        {isSetupMode && (
          <div className="flex items-start gap-3 bg-amber-500/10 border border-amber-500/30 rounded-lg px-4 py-3 mb-6">
            <AlertTriangle className="w-4 h-4 text-amber-400 mt-0.5 shrink-0" />
            <p className="text-xs text-amber-300 leading-relaxed">
              <span className="font-semibold">First-run setup.</span> No admin account exists yet.
              Create your credentials below. Use a strong password — this account controls your VPS security.
            </p>
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="username" className="text-sm text-foreground">Username</Label>
            <Input
              id="username"
              type="text"
              autoComplete="username"
              placeholder="admin"
              value={username}
              onChange={e => setUsername(e.target.value)}
              disabled={isPending}
              className="bg-card border-border focus:border-primary"
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="password" className="text-sm text-foreground">Password</Label>
            <div className="relative">
              <Input
                id="password"
                type={showPassword ? "text" : "password"}
                autoComplete={isSetupMode ? "new-password" : "current-password"}
                placeholder={isSetupMode ? "Min. 12 characters" : "••••••••••••"}
                value={password}
                onChange={e => setPassword(e.target.value)}
                disabled={isPending}
                className="bg-card border-border focus:border-primary pr-10"
              />
              <button
                type="button"
                onClick={() => setShowPassword(v => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                tabIndex={-1}
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          {isSetupMode && (
            <div className="space-y-1.5">
              <Label htmlFor="confirmPassword" className="text-sm text-foreground">Confirm Password</Label>
              <Input
                id="confirmPassword"
                type="password"
                autoComplete="new-password"
                placeholder="Repeat password"
                value={confirmPassword}
                onChange={e => setConfirmPassword(e.target.value)}
                disabled={isPending}
                className="bg-card border-border focus:border-primary"
              />
            </div>
          )}

          {errorMsg && (
            <div className="flex items-center gap-2 text-destructive text-sm bg-destructive/10 border border-destructive/30 rounded-lg px-3 py-2">
              <Lock className="w-3.5 h-3.5 shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}

          <Button
            type="submit"
            disabled={isPending}
            className="w-full bg-primary text-primary-foreground hover:bg-primary/90 active:scale-[0.98] transition-all"
          >
            {isPending ? (
              <span className="flex items-center gap-2">
                <span className="w-4 h-4 rounded-full border-2 border-primary-foreground border-t-transparent animate-spin" />
                {isSetupMode ? "Creating account…" : "Signing in…"}
              </span>
            ) : (
              <span className="flex items-center gap-2">
                <Shield className="w-4 h-4" />
                {isSetupMode ? "Create Admin Account" : "Sign In"}
              </span>
            )}
          </Button>
        </form>

        <p className="text-center text-xs text-muted-foreground mt-8">
          All actions are audit-logged · Access restricted to authenticated users
        </p>
      </div>
    </div>
  );
}
