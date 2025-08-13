output "load_balancer_ip" {
  value = google_compute_global_address.lb_ip.address
}

output "access_url" {
  value = "https://${google_compute_global_address.lb_ip.address}"
}