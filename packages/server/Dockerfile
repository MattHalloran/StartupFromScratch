# Dockerfile for server
FROM node:18-alpine3.20
ENV NODE_ENV=development
WORKDIR /app

# enable pnpm via Corepack
RUN corepack enable && corepack prepare pnpm@latest --activate

# install dependencies via pnpm (include devDependencies for type declarations)
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN NODE_ENV=development pnpm install --frozen-lockfile

COPY packages/server packages/server
COPY packages/shared packages/shared
COPY packages/prisma packages/prisma
COPY packages/redis packages/redis

RUN pnpm --filter @vrooli/server run build

EXPOSE 4000
CMD ["node", "packages/server/dist/index.js"] 