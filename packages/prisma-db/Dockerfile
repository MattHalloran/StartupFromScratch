# Dockerfile for prisma-db
FROM node:18-alpine3.20
WORKDIR /app
RUN corepack enable && corepack prepare yarn@4.0.0 --activate

COPY package.json yarn.lock .yarnrc.yml .yarn/ ./
RUN yarn install --immutable

COPY packages/prisma-db packages/prisma-db
WORKDIR /app/packages/prisma-db

# Generate client and run migrations
RUN yarn generate
CMD ["yarn", "dev"] 