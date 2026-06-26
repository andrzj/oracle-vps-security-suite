import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import NotFound from "@/pages/NotFound";
import { Route, Switch } from "wouter";
import ErrorBoundary from "./components/ErrorBoundary";
import { ThemeProvider } from "./contexts/ThemeContext";
import DashboardLayout from "./components/DashboardLayout";
import Home from "./pages/Home";
import Overview from "./pages/Overview";
import Alerts from "./pages/Alerts";
import Fail2Ban from "./pages/Fail2Ban";
import Firewall from "./pages/Firewall";
import Logs from "./pages/Logs";
import AuditLog from "./pages/AuditLog";

function Router() {
  return (
    <Switch>
      <Route path="/" component={Home} />
      <Route path="/dashboard">
        <DashboardLayout>
          <Overview />
        </DashboardLayout>
      </Route>
      <Route path="/alerts">
        <DashboardLayout>
          <Alerts />
        </DashboardLayout>
      </Route>
      <Route path="/fail2ban">
        <DashboardLayout>
          <Fail2Ban />
        </DashboardLayout>
      </Route>
      <Route path="/firewall">
        <DashboardLayout>
          <Firewall />
        </DashboardLayout>
      </Route>
      <Route path="/logs">
        <DashboardLayout>
          <Logs />
        </DashboardLayout>
      </Route>
      <Route path="/audit">
        <DashboardLayout>
          <AuditLog />
        </DashboardLayout>
      </Route>
      <Route component={NotFound} />
    </Switch>
  );
}

function App() {
  return (
    <ErrorBoundary>
      <ThemeProvider defaultTheme="dark">
        <TooltipProvider>
          <Toaster theme="dark" />
          <Router />
        </TooltipProvider>
      </ThemeProvider>
    </ErrorBoundary>
  );
}

export default App;
