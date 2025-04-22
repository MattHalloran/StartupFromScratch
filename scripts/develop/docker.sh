#!/usr/bin/env bash

# Starts development database containers (Postgres, Redis)
start_docker_db() {
  local env_file="$1"
  log_info "Starting Docker containers for Postgres and Redis using $env_file..."
  ENV_FILE="$env_file" docker-compose up -d postgres redis
} 