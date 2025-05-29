path "secret/data/vrooli/config/shared-all" {
  capabilities = ["read", "list"]
}
path "secret/data/vrooli/config/shared-all/*" { // In case of sub-paths
  capabilities = ["read", "list"]
} 