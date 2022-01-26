terraform {
  backend "gcs" {
    bucket = "terraform-bucket-kp"
  }
}

provider "google" {
  project = var.project
  zone    = var.zone
  region  = var.region
}

provider "google-beta" {
  project = var.project
  zone    = var.zone
  region  = var.region
}

resource "google_project_service" "services" {
  count              = length(var.project_services)
  service            = element(var.project_services, count.index)
  disable_on_destroy = false
}

resource "google_service_account" "node_sa" {
  account_id   = var.cluster_sa_name
  display_name = "cluster service account"
  depends_on   = [google_project_service.services]
}

resource "google_project_iam_member" "node_sa_roles" {
  count   = length(var.node_sa_roles)
  member  = format("serviceAccount:%s", google_service_account.node_sa.email)
  role    = element(var.node_sa_roles, count.index)
  project = var.project
}

resource "google_compute_network" "vpc_network" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpc_subnet" {
  name          = var.subnet_name
  region        = var.region
  network       = google_compute_network.vpc_network.id
  ip_cidr_range = var.subnet_ip_cidr_range

  secondary_ip_range {
    ip_cidr_range = var.services_ip_cidr_range
    range_name    = var.services_range_name
  }

  secondary_ip_range {
    ip_cidr_range = var.pods_ip_cidr_range
    range_name    = var.pods_range_name
  }
}

resource "google_container_cluster" "cluster" {
  name                      = var.cluster_name
  location                  = var.region
  initial_node_count        = 1
  remove_default_node_pool  = true
  network                   = google_compute_network.vpc_network.id
  subnetwork                = google_compute_subnetwork.vpc_subnet.id
  node_locations            = [var.zone]

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "cluster_node_pool" {
  name        = var.node_pool_name
  cluster     = google_container_cluster.cluster.id
  node_count  = var.node_count

  node_config {
    machine_type    = var.node_machine_type
    service_account = google_service_account.node_sa.email

    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }
}

resource "google_artifact_registry_repository" "docker_repo" {
  format        = "DOCKER"
  repository_id = var.docker_repo_name
  provider      = google-beta
  location      = var.region
  depends_on    = [google_project_service.services]
}