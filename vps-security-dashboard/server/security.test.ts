import { describe, expect, it, vi, beforeEach } from "vitest";
import { appRouter } from "./routers";
import type { TrpcContext } from "./_core/context";

// ── Helpers ──────────────────────────────────────────────────────────────────

function makeCtx(overrides?: Partial<TrpcContext>): TrpcContext {
  return {
    user: {
      id: 1,
      openId: "test-user",
      email: "test@example.com",
      name: "Test User",
      loginMethod: "manus",
      role: "admin",
      createdAt: new Date(),
      updatedAt: new Date(),
      lastSignedIn: new Date(),
    },
    req: { protocol: "https", headers: {} } as TrpcContext["req"],
    res: {
      clearCookie: vi.fn(),
    } as unknown as TrpcContext["res"],
    ...overrides,
  };
}

function makePublicCtx(): TrpcContext {
  return {
    user: null,
    req: { protocol: "https", headers: {} } as TrpcContext["req"],
    res: { clearCookie: vi.fn() } as unknown as TrpcContext["res"],
  };
}

// ── Auth tests ────────────────────────────────────────────────────────────────

describe("auth.me", () => {
  it("returns the current user when authenticated", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.auth.me();
    expect(result).toMatchObject({ id: 1, email: "test@example.com" });
  });

  it("returns null when not authenticated", async () => {
    const ctx = makePublicCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.auth.me();
    expect(result).toBeNull();
  });
});

describe("auth.logout", () => {
  it("clears the session cookie and returns success", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.auth.logout();
    expect(result).toEqual({ success: true });
    expect(ctx.res.clearCookie).toHaveBeenCalledOnce();
  });
});

// ── System health tests ───────────────────────────────────────────────────────

describe("health.current", () => {
  it("returns a health object with expected fields", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.health.current();
    expect(result).toHaveProperty("cpu");
    expect(result).toHaveProperty("memory");
    expect(result).toHaveProperty("disk");
    expect(result).toHaveProperty("uptime");
    expect(typeof result.cpu).toBe("number");
    expect(typeof result.memory).toBe("number");
    expect(typeof result.disk).toBe("number");
    expect(typeof result.uptime).toBe("number");
  });

  it("cpu usage is between 0 and 100", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.health.current();
    expect(result.cpu).toBeGreaterThanOrEqual(0);
    expect(result.cpu).toBeLessThanOrEqual(100);
  });

  it("memory usage is between 0 and 100", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.health.current();
    expect(result.memory).toBeGreaterThanOrEqual(0);
    expect(result.memory).toBeLessThanOrEqual(100);
  });
});

// ── Alerts tests ──────────────────────────────────────────────────────────────

describe("alerts.list", () => {
  it("returns an array of alerts", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.alerts.list({ limit: 10, onlyUnacknowledged: false });
    expect(Array.isArray(result)).toBe(true);
  });

  it("rejects unauthenticated requests", async () => {
    const ctx = makePublicCtx();
    const caller = appRouter.createCaller(ctx);
    await expect(caller.alerts.list({ limit: 10, onlyUnacknowledged: false })).rejects.toThrow();
  });
});

// ── Audit log tests ───────────────────────────────────────────────────────────

describe("audit.list", () => {
  it("returns paginated audit log entries", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.audit.list({ limit: 10, offset: 0 });
    expect(result).toHaveProperty("logs");
    expect(result).toHaveProperty("total");
    expect(Array.isArray(result.logs)).toBe(true);
  });

  it("respects the limit parameter", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.audit.list({ limit: 5, offset: 0 });
    expect(result.logs.length).toBeLessThanOrEqual(5);
  });

  it("rejects unauthenticated requests", async () => {
    const ctx = makePublicCtx();
    const caller = appRouter.createCaller(ctx);
    await expect(caller.audit.list({ limit: 10, offset: 0 })).rejects.toThrow();
  });
});

// ── Firewall rules tests ──────────────────────────────────────────────────────

describe("firewall.rules", () => {
  it("returns an array of firewall rules", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.firewall.rules();
    expect(Array.isArray(result)).toBe(true);
  });

  it("rejects unauthenticated requests", async () => {
    const ctx = makePublicCtx();
    const caller = appRouter.createCaller(ctx);
    await expect(caller.firewall.rules()).rejects.toThrow();
  });
});

// ── Fail2Ban history tests ────────────────────────────────────────────────────

describe("fail2ban.history", () => {
  it("returns an array of ban history entries", async () => {
    const ctx = makeCtx();
    const caller = appRouter.createCaller(ctx);
    const result = await caller.fail2ban.history({ limit: 10 });
    expect(Array.isArray(result)).toBe(true);
  });

  it("rejects unauthenticated requests", async () => {
    const ctx = makePublicCtx();
    const caller = appRouter.createCaller(ctx);
    await expect(caller.fail2ban.history({ limit: 10 })).rejects.toThrow();
  });
});
