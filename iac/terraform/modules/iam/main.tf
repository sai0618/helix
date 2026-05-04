locals {
  service_account_roles = flatten([
    for key, service_account in var.service_accounts : [
      for role in service_account.roles : {
        key  = key
        role = role
      }
    ]
  ])

  project_iam_roles = flatten([
    for persona, binding in var.project_iam_bindings : [
      for principal in binding.principals : [
        for role in binding.roles : {
          persona   = persona
          principal = principal
          role      = role
        }
      ]
    ]
  ])
}

resource "google_service_account" "service_accounts" {
  for_each = var.service_accounts

  project      = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
}

resource "google_project_iam_member" "service_account_roles" {
  for_each = {
    for binding in local.service_account_roles :
    "${binding.key}-${replace(binding.role, "/", "-")}" => binding
    if var.create_project_iam_bindings
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.service_accounts[each.value.key].email}"
}

resource "google_project_iam_member" "project_iam_roles" {
  for_each = {
    for binding in local.project_iam_roles :
    "${binding.persona}-${replace(replace(binding.principal, ":", "-"), "@", "-")}-${replace(binding.role, "/", "-")}" => binding
    if var.create_project_iam_bindings
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.principal
}
