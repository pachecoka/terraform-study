provider "google" {
  project = "reactive-study-337414"
  zone = "us-east1-c"
  region = "us-east1"
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
  count  = length(var.node_sa_roles)
  member = format("serviceAccount:%s", google_service_account.node_sa.email)
  role   = element(var.node_sa_roles, count.index)
  project = "reactive-study-337414"
}

resource "google_compute_network" "vpc_network" {
  name = "reactive-study-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpc_subnet" {
  name = "reactive-study-subnet"
  region = "us-east1"
  network = google_compute_network.vpc_network.id
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