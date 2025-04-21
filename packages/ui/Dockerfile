# Dockerfile for UI development
FROM node:18-alpine3.20

# Set working directory
WORKDIR /app

# Enable Yarn v4 (Berry)
RUN corepack enable && corepack prepare yarn@4.0.0 --activate

# Copy root Yarn configuration for workspaces
COPY package.json yarn.lock .yarnrc.yml .yarn/ ./

# Install dependencies
RUN yarn install --immutable

# Copy UI package and its dependencies
COPY packages/ui packages/ui
COPY packages/shared packages/shared
COPY packages/prisma-db packages/prisma-db
COPY packages/redis-db packages/redis-db

# Build UI (optional for prod preview; dev will run yarn dev directly)
# RUN cd packages/ui && yarn build

# Expose Vite dev server port
EXPOSE 3000

# Start Vite dev server for UI
CMD ["bash", "-lc", "yarn workspace @startupfromscratch/ui dev"] 