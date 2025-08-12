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
