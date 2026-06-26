# ─────────────────────────────────────────────────────────────────────────────
# VPS Security Dashboard — Production Dockerfile
# Multi-stage build: builder → production
# Base: node:24-alpine (Node.js 24 LTS "Krypton")
#
# Database: SQLite via better-sqlite3 (single file, zero extra services)
# The SQLite file is stored in /app/data/ which is mounted as a Docker volume.
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM node:24-alpine AS builder

# Build dependencies: python3/make/g++ are required for better-sqlite3 native bindings
RUN apk add --no-cache python3 make g++ libc6-compat

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy package files first for better layer caching
COPY package.json pnpm-lock.yaml ./
COPY patches/ ./patches/

# Install all dependencies (including devDependencies for build)
# better-sqlite3 native bindings are compiled here
RUN pnpm install --frozen-lockfile

# Copy source files
COPY . .

# Build the application
RUN pnpm run build

# ── Stage 2: Production ───────────────────────────────────────────────────────
FROM node:24-alpine AS production

# Runtime dependencies:
#   python3/make/g++ — required to rebuild better-sqlite3 native bindings for production
#   sudo             — for running ufw and fail2ban-client with least privilege
#   wget             — for Docker health checks
#   tzdata           — timezone data
#   procps           — process utilities (ps, etc.)
RUN apk add --no-cache \
    python3 make g++ \
    sudo \
    wget \
    tzdata \
    procps

# Create non-root user for the app
RUN addgroup -g 1001 -S dashboard && \
    adduser -S -u 1001 -G dashboard dashboard

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml ./
COPY patches/ ./patches/

# Install production dependencies only
# This recompiles better-sqlite3 native bindings for the production Alpine image
RUN pnpm install --frozen-lockfile --prod

# Copy built artifacts from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/client/dist ./client/dist

# Copy drizzle schema and migrations
COPY --from=builder /app/drizzle ./drizzle

# Create SQLite data directory and set ownership
# This directory is mounted as a Docker volume for persistence
RUN mkdir -p /app/data && chown dashboard:dashboard /app/data

# Switch to non-root user
USER dashboard

# Expose app port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

# Start the application
CMD ["node", "dist/index.js"]
