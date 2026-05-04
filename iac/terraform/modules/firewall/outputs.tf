output "firewall_rule_names" {
  description = "Created firewall rule names."
  value = compact([
    google_compute_firewall.allow_internal.name,
    google_compute_firewall.allow_google_health_checks.name,
    try(google_compute_firewall.allow_iap_admin[0].name, null),
  ])
}
