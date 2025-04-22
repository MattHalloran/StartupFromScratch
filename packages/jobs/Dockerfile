# Dockerfile for jobs
FROM node:18-alpine3.20
WORKDIR /app

# enable pnpm via Corepack
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy project manifests and workspace packages
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages/jobs packages/jobs
COPY packages/shared packages/shared
COPY packages/prisma packages/prisma
COPY packages/redis packages/redis

# Install dependencies and generate Prisma client for workspace
RUN pnpm install --frozen-lockfile \
    && pnpm --filter @vrooli/prisma run generate

# Build jobs package
RUN pnpm --filter @vrooli/jobs run build

# Default command to run jobs
CMD ["node", "packages/jobs/dist/index.js"] 