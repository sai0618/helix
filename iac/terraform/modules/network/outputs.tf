output "vpc_name" {
  description = "VPC name."
  value       = google_compute_network.vpc.name
}

output "vpc_id" {
  description = "VPC ID."
  value       = google_compute_network.vpc.id
}

output "vpc_self_link" {
  description = "VPC self link."
  value       = google_compute_network.vpc.self_link
}

output "subnet_names" {
  description = "Subnet names by key."
  value = {
    for key, subnet in google_compute_subnetwork.subnets :
    key => subnet.name
  }
}

output "subnet_self_links" {
  description = "Subnet self links by key."
  value = {
    for key, subnet in google_compute_subnetwork.subnets :
    key => subnet.self_link
  }
}
