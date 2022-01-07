provider "google" {
  project = "reactive-study-337414"
  zone    = "us-east1-c"
  region  = "us-east1"
}

provider "google-beta" {
  project = "reactive-study-337414"
  zone    = "us-east1-c"
  region  = "us-east1"
}

resource "google_project_service" "services" {
  count              = length(var.project_services)
  service            = element(var.project_services, count.index)
  disable_on_destroy = false
}

resource "google_service_account" "node_sa" {
  account_id   = "node-sa"
  display_name = "cluster service account"
  depends_on   = [google_project_service.services]
}

resource "google_project_iam_member" "node_sa_roles" {
  count   = length(var.node_sa_roles)
  member  = format("serviceAccount:%s", google_service_account.node_sa.email)
  role    = element(var.node_sa_roles, count.index)
  project = "reactive-study-337414"
}

resource "google_compute_network" "vpc_network" {
  name                    = "reactive-study-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpc_subnet" {
  name          = "reactive-study-subnet"
  region        = "us-east1"
  network       = google_compute_network.vpc_network.id
  ip_cidr_range = "10.2.0.0/16"

  secondary_ip_range {
    ip_cidr_range = "10.100.0.0/20"
    range_name    = "services-ip-range"
  }

  secondary_ip_range {
    ip_cidr_range = "10.96.0.0/14"
    range_name    = "pods-ip-range"
  }
}

resource "google_container_cluster" "cluster" {
  name                      = "reactive-study-cluster"
  location                  = "us-east1"
  initial_node_count        = 1
  remove_default_node_pool  = true
  network                   = google_compute_network.vpc_network.id
  subnetwork                = google_compute_subnetwork.vpc_subnet.id
  node_locations            = ["us-east1-c"]

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-ip-range"
    services_secondary_range_name = "services-ip-range"
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "google_container_node_pool" "cluster_node_pool" {
  name        = "cluster-node-pool"
  cluster     = google_container_cluster.cluster.id
  node_count  = 3

  node_config {
    machine_type    = "g1-small"
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

resource "google_artifact_registry_repository" "artifact_repo" {
  format        = "DOCKER"
  repository_id = "docker-images"
  provider      = google-beta
  location      = "us-east1"
  depends_on    = [google_project_service.services]
}