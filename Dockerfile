# syntax=docker/dockerfile:1.4

### Base stage: install dependencies and build workspace
FROM node:18-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
WORKDIR /usr/src/app
ENV NODE_ENV=development

# Enable Corepack and prepare pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy manifest files and prime cache
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# Copy workspace package.json files for workspace detection
COPY packages/server/package.json packages/server/package.json
COPY packages/jobs/package.json packages/jobs/package.json
COPY packages/ui/package.json packages/ui/package.json
COPY packages/shared/package.json packages/shared/package.json
COPY packages/prisma/package.json packages/prisma/package.json
COPY packages/redis/package.json packages/redis/package.json
RUN --mount=type=cache,id=pnpm-store,target=/usr/local/share/pnpm-store pnpm fetch

# Install all dependencies, including devDependencies, across all workspaces
RUN --mount=type=cache,id=pnpm-store,target=/usr/local/share/pnpm-store \
    pnpm install --frozen-lockfile

# Copy full source and build all packages
COPY . .
# Generate Prisma client for correct schema
RUN pnpm --filter @vrooli/prisma run generate -- --schema=packages/prisma/prisma/schema.prisma

# Build shared utilities
RUN pnpm --filter @vrooli/shared run build

# Build UI package (produces dist folder)
RUN pnpm --filter @vrooli/ui run build

# Build jobs package
RUN pnpm --filter @vrooli/jobs run build

# Build server package: shared, compile, and copy static files
RUN pnpm --filter @vrooli/server run build:shared \
    && pnpm --filter @vrooli/server run build:compile \
    && pnpm --filter @vrooli/server run copy


### Server image: run compiled server code
FROM node:18-slim AS server
ENV NODE_ENV=production
WORKDIR /usr/src/app
COPY --from=base /usr/src/app/node_modules ./node_modules
COPY --from=base /usr/src/app/packages/server/dist ./packages/server/dist
EXPOSE 4000
CMD ["node", "packages/server/dist/index.js"]


### Jobs image: run compiled jobs code
FROM node:18-slim AS jobs
WORKDIR /usr/src/app
COPY --from=base /usr/src/app/node_modules ./node_modules
COPY --from=base /usr/src/app/packages/jobs/dist ./packages/jobs/dist
CMD ["node", "packages/jobs/dist/index.js"]


### UI development image: run Vite dev server
FROM node:18-slim AS ui-dev
WORKDIR /usr/src/app
COPY --from=base /usr/src/app/node_modules ./node_modules
COPY --from=base /usr/src/app .
EXPOSE 3000
CMD ["pnpm", "--filter", "@vrooli/ui", "run", "dev", "--", "--host", "0.0.0.0", "--port", "3000"] 