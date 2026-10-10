locals {
  stack   = yamldecode(file("${var.project}/stack.yaml"))
  grafana = local.stack.apps.grafana
  host    = cidrhost(local.stack.network.cidr, 1)

  # Mimir and Loki by their Consul names (the apps' job names), resolved through
  # the platform's Consul DNS: found wherever they run — in the mesh by their mesh
  # names, through Envoy. stack.yaml can name others.
  mesh       = try(local.grafana.mesh, {})
  domain     = try(local.mesh.enabled, false) ? "virtual.consul" : "service.consul"
  mimir_host = try(local.grafana.mimir_host, "mimir.${local.domain}")
  loki_host  = try(local.grafana.loki_host, "loki.${local.domain}")

  datasources = [
    { name = "Mimir", type = "prometheus", url = "http://${local.mimir_host}:${try(local.grafana.mimir_port, 9009)}/prometheus", is_default = true },
    { name = "Loki", type = "loki", url = "http://${local.loki_host}:${try(local.grafana.loki_port, 3100)}" },
  ]
}

module "grafana" {
  source = "git::https://github.com/eugene-panin/terraform-nomad-grafana.git?ref=v0.1.5"

  hostname    = "grafana.${local.stack.infra_domain}"
  datasources = local.datasources
  dns_servers = try(local.grafana.dns_servers, [local.host])
  # The Consul service mesh, as a client: off unless stack.yaml turns it on
  # (mesh: {enabled}); allow grafana in Mimir's and Loki's intentions.
  mesh          = local.mesh
  vault_kv_path = var.vault_kv_path
}
