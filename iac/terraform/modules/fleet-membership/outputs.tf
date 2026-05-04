output "memberships" {
  description = "Fleet membership details by cluster key."
  value = {
    for key, membership in google_gke_hub_membership.memberships :
    key => {
      name                = membership.name
      membership_id       = membership.membership_id
      membership_location = membership.location
    }
  }
}
