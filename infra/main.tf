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

  # The platform's single sign-on (sso in stack.yaml): Grafana signs people in
  # through Vault's OIDC provider, the admins as Admins, with no anonymous reading.
  sso       = try(local.stack.sso, null) != null
  vault_url = "https://vault.${local.stack.infra_domain}"
  issuer    = "${local.vault_url}/v1/identity/oidc/provider/platform"
}

# Grafana's client of Vault's OIDC provider, with the platform's key and the admins'
# assignment (made by the platform's sso).
resource "vault_identity_oidc_client" "grafana" {
  count = local.sso ? 1 : 0

  name             = "grafana"
  key              = "platform"
  assignments      = ["platform-admins"]
  client_type      = "confidential"
  id_token_ttl     = 3600
  access_token_ttl = 3600
  redirect_uris    = ["https://grafana.${local.stack.infra_domain}/login/generic_oauth"]
}

module "grafana" {
  source = "git::https://github.com/eugene-panin/terraform-nomad-grafana.git?ref=v0.1.6"

  hostname    = "grafana.${local.stack.infra_domain}"
  datasources = local.datasources
  dns_servers = try(local.grafana.dns_servers, [local.host])
  # The Consul service mesh, as a client: off unless stack.yaml turns it on
  # (mesh: {enabled}); allow grafana in Mimir's and Loki's intentions.
  mesh = local.mesh
  oidc = local.sso ? {
    client_id     = vault_identity_oidc_client.grafana[0].client_id
    client_secret = vault_identity_oidc_client.grafana[0].client_secret
    auth_url      = "${local.vault_url}/ui/vault/identity/oidc/provider/platform/authorize"
    token_url     = "${local.issuer}/token"
    api_url       = "${local.issuer}/userinfo"
  } : null
  anonymous_viewer = try(local.grafana.anonymous_viewer, !local.sso)
  vault_kv_path    = var.vault_kv_path
}
