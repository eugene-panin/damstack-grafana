locals {
  stack   = yamldecode(file("${var.project}/stack.yaml"))
  grafana = local.stack.apps.grafana
  host    = cidrhost(local.stack.network.cidr, 1)

  # Mimir and Loki by their Consul names (the apps' job names), resolved through
  # the platform's Consul DNS: found wherever they run. stack.yaml can name others.
  mimir_host = try(local.grafana.mimir_host, "mimir.service.consul")
  loki_host  = try(local.grafana.loki_host, "loki.service.consul")

  datasources = [
    { name = "Mimir", type = "prometheus", url = "http://${local.mimir_host}:${try(local.grafana.mimir_port, 9009)}/prometheus", is_default = true },
    { name = "Loki", type = "loki", url = "http://${local.loki_host}:${try(local.grafana.loki_port, 3100)}" },
  ]
}

module "grafana" {
  source = "git::https://github.com/eugene-panin/terraform-nomad-grafana.git?ref=v0.1.2"

  hostname      = "grafana.${local.stack.infra_domain}"
  datasources   = local.datasources
  dns_servers   = try(local.grafana.dns_servers, [local.host])
  vault_kv_path = var.vault_kv_path
}
