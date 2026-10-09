locals {
  stack   = yamldecode(file("${var.project}/stack.yaml"))
  grafana = local.stack.apps.grafana
  host    = cidrhost(local.stack.network.cidr, 1)

  datasources = [
    { name = "Mimir", type = "prometheus", url = "http://${local.host}:${try(local.grafana.mimir_port, 9009)}/prometheus", is_default = true },
    { name = "Loki", type = "loki", url = "http://${local.host}:${try(local.grafana.loki_port, 3100)}" },
  ]
}

module "grafana" {
  source = "git::https://github.com/eugene-panin/terraform-nomad-grafana.git?ref=v0.1.0"

  hostname      = "grafana.${local.stack.infra_domain}"
  datasources   = local.datasources
  vault_kv_path = var.vault_kv_path
}
