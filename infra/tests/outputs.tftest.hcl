mock_provider "consul" {}
mock_provider "nomad" {}
mock_provider "vault" {}
mock_provider "random" {}

variables {
  state_passphrase = "a passphrase for the test only"
  vault_kv_path    = "secret"
}

run "it_serves_grafana_on_the_infra_domain" {
  command = apply

  assert {
    condition     = output.url == "https://grafana.infra.example.org"
    error_message = "Grafana is not served on grafana.<infra_domain>."
  }

  assert {
    condition     = output.service_name == "grafana"
    error_message = "The Consul service is not grafana."
  }

  assert {
    condition     = output.admin_secret == "default/grafana/admin"
    error_message = "The admin credential is not at the expected Vault name."
  }
}
