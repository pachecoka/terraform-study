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

  private_ip_google_access = true

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

  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes = true
    master_ipv4_cidr_block = "172.16.0.16/28"
  }

  network_policy {
    enabled = true
  }

  workload_identity_config {
    workload_pool = format("%s.svc.id.goog", "reactive-study-337414")
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = format("%s/32", google_compute_instance.bastion.network_interface.0.network_ip)
      display_name = "bastion"
    }
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
  provider    = google-beta

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

    labels = {
      cluster = google_container_cluster.cluster.name
    }

    metadata = {
      // Set metadata on the VM to supply more entropy.
      google-compute-enable-virtio-rng = true
      // Explicitly remove GCE legacy metadata API endpoint.
      disabe-legacy-endpoints = true
    }

    // Enable workload identity on this node pool.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

resource "google_artifact_registry_repository" "artifact_repo" {
  format        = "DOCKER"
  repository_id = "docker-images"
  provider      = google-beta
  location      = "us-east1"
  depends_on    = [google_project_service.services]
}

//to create VMs
resource "google_compute_instance" "bastion" {
  machine_type = "g1-small"
  name         = "bastion-vm"
  zone         = "us-east1-c"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet.name
    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    email = google_service_account.node_sa.email
    scopes = ["cloud-platform"]
  }

  tags = ["bastion-vm"]

  metadata_startup_script = <<-EOF
  sudo apt-get update -y
  sudo apt-get install -y tinyproxy
  EOF
}

resource "google_compute_firewall" "allow-inbound-ssh" {
  name    = "allow-inbound-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  source_tags = ["bastion-vm"]
}

resource "google_compute_firewall" "allow-inbound-nginx" {
  name    = "allow-inbound-nginx"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports = ["443", "8443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_router" "router" {
  name    = "router"
  region  = "us-east1"
  network = google_compute_network.vpc_network.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_address" "address" {
  name    = format("%s-nat-ip", "reactive-study-cluster")
  region  = "us-east1"

  depends_on = [
    google_project_service.services
  ]
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat"
  router                             = google_compute_router.router.name
  region                             = "us-east1"
  nat_ips                            = [google_compute_address.address.self_link]
  nat_ip_allocate_option             = "MANUAL_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                     = google_compute_subnetwork.vpc_subnet.id
    source_ip_ranges_to_nat  = [
      "PRIMARY_IP_RANGE",
      "LIST_OF_SECONDARY_IP_RANGES"
    ]
    secondary_ip_range_names = ["pods-ip-range", "services-ip-range"]
  }
}
