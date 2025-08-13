terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "scalabit-proj-bucket"
    prefix = "terraform/scalabitstate"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_secret_manager_secret_version" "oauth2_client_id" {
  secret = "scalabit-oauth-client-id"
}

data "google_secret_manager_secret_version" "oauth2_client_secret" {
  secret = "scalabit-oauth-client-secret"
}

resource "google_compute_network" "vpc_network" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_router" "router" {
  name    = "${var.project_name}-router"
  region  = var.region
  network = google_compute_network.vpc_network.id
}
resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
resource "google_compute_firewall" "allow_iap" {
  name    = "allow-iap"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "6443"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.project_name}-node"]
}
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  source_ranges = ["10.0.0.0/24"]
  target_tags   = ["${var.project_name}-node"]
}

resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "${var.project_name}-repo"
  description   = "Image repository for Scalabit Project"
  format        = "DOCKER"
}
resource "google_service_account" "scalabit_sa" {
  account_id   = "${var.project_name}-sa"
  display_name = "Scalabit k3s Node Service Account"
}

resource "google_compute_instance" "scalabit_k3s_node" {
  name         = "vm-${var.project_name}-k3s-node"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["${var.project_name}-node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
  }

  service_account {
    email  = google_service_account.scalabit_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/setupscript.sh", {
    project_id = var.project_id
    region     = var.region
    repo_name  = google_artifact_registry_repository.repo.name
  })
}
resource "google_compute_global_address" "lb_ip" {
  name = "${var.project_name}-k3s-lb-ip"
}
resource "google_compute_backend_service" "backend" {
  name                  = "${var.project_name}-k3s-backend"
  protocol              = "HTTP"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  iap {
    oauth2_client_id     = data.google_secret_manager_secret_version.oauth2_client_id.secret_data
    oauth2_client_secret = data.google_secret_manager_secret_version.oauth2_client_secret.secret_data
  }
  backend {
    group = google_compute_instance_group.k3s_group.id
  }
  health_checks = [google_compute_health_check.health_check.id]
}
resource "google_compute_instance_group" "k3s_group" {
  name      = "${var.project_name}-k3s-group"
  zone      = var.zone
  instances = [google_compute_instance.scalabit_k3s_node.id]

  named_port {
    name = "http"
    port = "80"
  }
}
resource "google_compute_health_check" "health_check" {
  name               = "${var.project_name}-k3s-health-check"
  timeout_sec        = 5
  check_interval_sec = 10

  http_health_check {
    port         = "80"
    request_path = "/health"
  }
}
resource "google_compute_url_map" "url_map" {
  name            = "${var.project_name}-k3s-url-map"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "${var.project_name}-k3s-https-proxy"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert.id]
}
resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  name = "${var.project_name}-k3s-ssl-cert"
  managed {
    domains = ["app.swaydevstan.com"]
  }
}
resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name       = "${var.project_name}-k3s-forwarding-rule"
  target     = google_compute_target_https_proxy.https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.lb_ip.address
}