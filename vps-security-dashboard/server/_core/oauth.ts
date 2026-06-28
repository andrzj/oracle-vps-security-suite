/**
 * Self-contained credential authentication routes.
 * Replaces Manus OAuth — no external provider required.
 *
 * POST /api/auth/setup        { username, password } → first-run admin creation
 * POST /api/auth/login        { username, password } → sets session cookie
 * POST /api/auth/logout       → clears session cookie
 * GET  /api/auth/me           → returns current admin info (no password hash)
 * GET  /api/auth/setup-status → { setupRequired: boolean }
 */
import type { Express, Request, Response } from "express";
import {
  verifyAdminCredentials,
  signAdminJWT,
  verifyAdminJWT,
  getAdminById,
  countAdmins,
  createAdmin,
} from "../db";
import { COOKIE_NAME } from "../../shared/const";
import { getSessionCookieOptions } from "./cookies";

const SESSION_MAX_AGE_MS = 8 * 60 * 60 * 1000; // 8 hours

function parseCookies(cookieHeader: string): Record<string, string> {
  return Object.fromEntries(
    cookieHeader.split(";").map(c => {
      const [k, ...v] = c.trim().split("=");
      return [k?.trim() ?? "", decodeURIComponent(v.join("="))];
    })
  );
}

// Kept as a named export so context.ts can import it directly.
export async function authenticateRequest(
  req: Request
): Promise<{ id: number; username: string; role: string } | null> {
  const cookies = parseCookies(req.headers.cookie ?? "");
  const token = cookies[COOKIE_NAME];
  if (token) return verifyAdminJWT(token);

  // Fallback: Bearer token for API clients / curl usage
  const authHeader = req.headers.authorization;
  if (authHeader?.startsWith("Bearer ")) {
    return verifyAdminJWT(authHeader.slice(7));
  }
  return null;
}

export function registerOAuthRoutes(app: Express) {
  // ── First-run setup ───────────────────────────────────────────────────────
  app.post("/api/auth/setup", async (req: Request, res: Response) => {
    try {
      if (countAdmins() > 0) {
        return res.status(403).json({ error: "Setup already completed" });
      }
      const { username, password } = req.body as { username?: string; password?: string };
      if (!username || !password) {
        return res.status(400).json({ error: "username and password are required" });
      }
      if (username.length < 3 || username.length > 32) {
        return res.status(400).json({ error: "username must be 3–32 characters" });
      }
      if (password.length < 12) {
        return res.status(400).json({ error: "password must be at least 12 characters" });
      }
      const admin = await createAdmin(username, password, "admin");
      const token = await signAdminJWT(admin);
      const cookieOptions = getSessionCookieOptions(req);
      res.cookie(COOKIE_NAME, token, { ...cookieOptions, maxAge: SESSION_MAX_AGE_MS });
      return res.json({ success: true, username: admin.username, role: admin.role });
    } catch (err) {
      console.error("[Auth] Setup failed", err);
      return res.status(500).json({ error: "Setup failed" });
    }
  });

  // ── Login ─────────────────────────────────────────────────────────────────
  app.post("/api/auth/login", async (req: Request, res: Response) => {
    try {
      const { username, password } = req.body as { username?: string; password?: string };
      if (!username || !password) {
        return res.status(400).json({ error: "username and password are required" });
      }
      const admin = await verifyAdminCredentials(username, password);
      if (!admin) {
        // Uniform delay to prevent timing-based username enumeration
        await new Promise(r => setTimeout(r, 300 + Math.random() * 200));
        return res.status(401).json({ error: "Invalid credentials" });
      }
      const token = await signAdminJWT(admin);
      const cookieOptions = getSessionCookieOptions(req);
      res.cookie(COOKIE_NAME, token, { ...cookieOptions, maxAge: SESSION_MAX_AGE_MS });
      return res.json({ success: true, username: admin.username, role: admin.role });
    } catch (err) {
      console.error("[Auth] Login failed", err);
      return res.status(500).json({ error: "Login failed" });
    }
  });

  // ── Logout ────────────────────────────────────────────────────────────────
  app.post("/api/auth/logout", (req: Request, res: Response) => {
    const cookieOptions = getSessionCookieOptions(req);
    res.clearCookie(COOKIE_NAME, { ...cookieOptions, maxAge: -1 });
    return res.json({ success: true });
  });

  // ── Me ────────────────────────────────────────────────────────────────────
  app.get("/api/auth/me", async (req: Request, res: Response) => {
    try {
      const payload = await authenticateRequest(req);
      if (!payload) return res.status(401).json({ error: "Not authenticated" });
      const admin = getAdminById(payload.id);
      if (!admin) return res.status(401).json({ error: "Admin not found" });
      return res.json({
        id: admin.id,
        username: admin.username,
        role: admin.role,
        lastSignedIn: admin.lastSignedIn,
      });
    } catch (err) {
      return res.status(500).json({ error: "Failed to get user info" });
    }
  });

  // ── Setup status (public — used by login page to decide which form to show) ─
  app.get("/api/auth/setup-status", (_req: Request, res: Response) => {
    return res.json({ setupRequired: countAdmins() === 0 });
  });
}
