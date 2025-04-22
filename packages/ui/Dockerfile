# Dockerfile for UI development
FROM node:18-alpine3.20

# Set working directory
WORKDIR /app

# Enable pnpm via Corepack
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy pnpm lockfile and workspace config
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Install dependencies via pnpm
RUN pnpm install --frozen-lockfile

# Copy UI package and its dependencies
COPY packages/ui packages/ui
COPY packages/shared packages/shared
COPY packages/prisma packages/prisma
COPY packages/redis packages/redis

# Build UI (optional for prod preview; dev will run pnpm run dev directly)
# RUN cd packages/ui && pnpm run build

# Expose Vite dev server port
EXPOSE 3000

# Start Vite dev server for UI
CMD ["bash", "-lc", "pnpm --filter @vrooli/ui run dev"] 