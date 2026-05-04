output "router_names" {
  description = "Cloud Router names by region."
  value = {
    for region, router in google_compute_router.routers :
    region => router.name
  }
}

output "nat_names" {
  description = "Cloud NAT names by region."
  value = {
    for region, nat in google_compute_router_nat.nats :
    region => nat.name
  }
}
