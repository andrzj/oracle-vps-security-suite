import type { CreateExpressContextOptions } from "@trpc/server/adapters/express";
import type { Admin } from "../../drizzle/schema";
import { authenticateRequest } from "./oauth";

export type AdminSession = {
  id: number;
  username: string;
  role: "admin" | "viewer";
};

export type TrpcContext = {
  req: CreateExpressContextOptions["req"];
  res: CreateExpressContextOptions["res"];
  user: AdminSession | null;
};

export async function createContext(
  opts: CreateExpressContextOptions
): Promise<TrpcContext> {
  let user: AdminSession | null = null;

  try {
    const payload = await authenticateRequest(opts.req);
    if (payload) {
      user = {
        id: payload.id,
        username: payload.username,
        role: (payload.role === "admin" || payload.role === "viewer") ? payload.role : "viewer",
      };
    }
  } catch {
    user = null;
  }

  return {
    req: opts.req,
    res: opts.res,
    user,
  };
}
