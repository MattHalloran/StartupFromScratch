path "secret/data/vrooli/secrets/shared-server-jobs" {
  capabilities = ["read", "list"]
}
path "secret/data/vrooli/secrets/shared-server-jobs/*" { // In case of sub-paths
  capabilities = ["read", "list"]
} 