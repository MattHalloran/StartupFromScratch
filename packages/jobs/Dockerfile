# Dockerfile for jobs
FROM node:18-alpine3.20
WORKDIR /app

# enable pnpm via Corepack
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install dependencies via pnpm
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

# Copy relevant packages
COPY packages/jobs packages/jobs
COPY packages/shared packages/shared
COPY packages/prisma packages/prisma
COPY packages/redis packages/redis

# Build jobs package with pnpm
RUN pnpm --filter @vrooli/jobs run build

# Default command to run jobs
CMD ["node", "packages/jobs/dist/index.js"] 