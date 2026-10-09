output "url" {
  description = "URL Grafana is served on."
  value       = module.grafana.url
}

output "service_name" {
  description = "Consul service name of Grafana."
  value       = module.grafana.service_name
}

output "admin_secret" {
  description = "Vault KV name (under the mount) of the admin credential; a consumer reads it to push dashboards and alerts."
  value       = module.grafana.admin_secret
}

output "admin_password" {
  description = "Grafana admin password."
  value       = module.grafana.admin_password
  sensitive   = true
}
