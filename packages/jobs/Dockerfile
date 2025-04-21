# Dockerfile for jobs
FROM node:18-alpine3.20
WORKDIR /app

# enable Yarn v4
RUN corepack enable && corepack prepare yarn@4.0.0 --activate

# Install dependencies
COPY package.json yarn.lock .yarnrc.yml .yarn/ ./
RUN yarn install --immutable

# Copy relevant packages
COPY packages/jobs packages/jobs
COPY packages/shared packages/shared
COPY packages/prisma-db packages/prisma-db
COPY packages/redis-db packages/redis-db

# Build jobs package
RUN yarn workspace @startupfromscratch/jobs build

# Default command to run jobs
CMD ["node", "packages/jobs/dist/index.js"] 