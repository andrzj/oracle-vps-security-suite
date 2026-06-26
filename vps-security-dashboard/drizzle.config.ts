import { defineConfig } from "drizzle-kit";

const dbPath = process.env.SQLITE_DB_PATH ?? "file:./data/security-dashboard.db";

export default defineConfig({
  schema: "./drizzle/schema.ts",
  out: "./drizzle",
  dialect: "sqlite",
  dbCredentials: {
    url: dbPath,
  },
});
