# Dockerfile for server
FROM node:18-alpine3.20
WORKDIR /app

# enable Yarn v4
RUN corepack enable && corepack prepare yarn@4.0.0 --activate

# install dependencies and build
COPY package.json yarn.lock .yarnrc.yml .yarn/ ./
RUN yarn install --immutable

COPY packages/server packages/server
COPY packages/shared packages/shared
COPY packages/prisma-db packages/prisma-db
COPY packages/redis-db packages/redis-db

RUN yarn workspace @startupfromscratch/server build

EXPOSE 4000
CMD ["node", "packages/server/dist/index.js"] 