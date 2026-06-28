import { trpc } from "@/lib/trpc";
import { useCallback } from "react";

export type AuthUser = {
  id: number;
  username: string;
  role: "admin" | "viewer";
};

type UseAuthOptions = {
  redirectOnUnauthenticated?: boolean;
};

export function useAuth(options?: UseAuthOptions) {
  const { redirectOnUnauthenticated = false } = options ?? {};
  const utils = trpc.useUtils();

  const meQuery = trpc.auth.me.useQuery(undefined, {
    retry: false,
    refetchOnWindowFocus: false,
  });

  const logoutMutation = trpc.auth.logout.useMutation({
    onSuccess: () => {
      utils.auth.me.setData(undefined, null);
      // Redirect to login page after logout
      window.location.href = "/";
    },
  });

  const logout = useCallback(() => {
    logoutMutation.mutate();
  }, [logoutMutation]);

  const user = meQuery.data as AuthUser | null | undefined;
  const isAuthenticated = Boolean(user);

  // Redirect to login if unauthenticated and option is set
  if (
    redirectOnUnauthenticated &&
    !meQuery.isLoading &&
    !isAuthenticated &&
    typeof window !== "undefined" &&
    window.location.pathname !== "/"
  ) {
    window.location.href = "/";
  }

  return {
    user,
    loading: meQuery.isLoading || logoutMutation.isPending,
    error: meQuery.error ?? logoutMutation.error ?? null,
    isAuthenticated,
    logout,
    refresh: () => meQuery.refetch(),
  };
}
