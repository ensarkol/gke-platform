resource "random_password" "grafana_admin" {
  length  = 20
  special = false
}

locals {
  grafana_admin_password = coalesce(var.grafana_admin_password, random_password.grafana_admin.result)
}
