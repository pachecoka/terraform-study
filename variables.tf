variable "project_services" {
  type = list(string)
  default = null
}

variable "node_sa_roles" {
  type = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/compute.serviceAgent",
    "roles/container.serviceAgent",
    "roles/artifactregistry.admin"
  ]
}