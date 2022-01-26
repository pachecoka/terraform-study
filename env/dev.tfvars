zone    = "us-east1-c"
region  = "us-east1"

project_services = [
  "compute.googleapis.com",
  "container.googleapis.com",
  "artifactregistry.googleapis.com",
  "servicenetworking.googleapis.com",
  "cloudresourcemanager.googleapis.com"
]

# service account
cluster_sa_name = "node-sa"
node_sa_roles   = [
  "roles/logging.logWriter",
  "roles/monitoring.metricWriter",
  "roles/monitoring.viewer",
  "roles/compute.serviceAgent",
  "roles/container.serviceAgent",
  "roles/artifactregistry.admin"
]

# network
vpc_name               = "reactive-study-vpc"
subnet_name            = "reactive-study-subnet"
subnet_ip_cidr_range   = "10.2.0.0/16"
services_ip_cidr_range = "10.100.0.0/20"
pods_ip_cidr_range     = "10.96.0.0/14"
services_range_name    = "services-ip-range"
pods_range_name        = "pods-ip-range"

# cluster
cluster_name      = "reactive-study-cluster"
node_pool_name    = "cluster-node-pool"
node_count        = 3
node_machine_type = "g1-small"

# artifact registry
docker_repo_name = "docker-dev-images"
