# Dockerfile for prisma
FROM node:18-alpine3.20
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY packages/prisma packages/prisma
WORKDIR /app/packages/prisma

# Generate client and run migrations
RUN pnpm run generate
CMD ["pnpm", "run", "dev"] 