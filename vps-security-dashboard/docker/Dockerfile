# ─────────────────────────────────────────────────────────────────────────────
# VPS Security Dashboard — Production Dockerfile
# Multi-stage build: builder → production
# Base: node:24-alpine (Node.js 24 LTS "Krypton")
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM node:24-alpine AS builder

# Install build dependencies
RUN apk add --no-cache python3 make g++ libc6-compat

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy package files first for better layer caching
COPY package.json pnpm-lock.yaml ./
COPY patches/ ./patches/

# Install all dependencies (including devDependencies for build)
RUN pnpm install --frozen-lockfile

# Copy source files
COPY . .

# Build the application
RUN pnpm run build

# ── Stage 2: Production ───────────────────────────────────────────────────────
FROM node:24-alpine AS production

# Install runtime dependencies only
RUN apk add --no-cache \
    # For running system commands
    sudo \
    # For health checks
    wget \
    # Timezone data
    tzdata \
    # Process utilities
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
RUN pnpm install --frozen-lockfile --prod

# Copy built artifacts from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/client/dist ./client/dist

# Copy drizzle migrations
COPY --from=builder /app/drizzle ./drizzle

# Create data directory
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
