variable "project" {
  type    = string
  default = null
}

variable "zone" {
  type    = string
  default = null
}

variable "region" {
  type    = string
  default = null
}

variable "project_services" {
  type = list(string)
  default = null
}

# service account
variable "cluster_sa_name" {
  type    = string
  default = null
}

variable "node_sa_roles" {
  type = list(string)
  default = null
}

# network
variable "vpc_name" {
  type    = string
  default = null
}

variable "subnet_name" {
  type    = string
  default = null
}

variable "subnet_ip_cidr_range" {
  type    = string
  default = null
}

variable "services_ip_cidr_range" {
  type    = string
  default = null
}

variable "pods_ip_cidr_range" {
  type    = string
  default = null
}

variable "services_range_name" {
  type    = string
  default = null
}

variable "pods_range_name" {
  type    = string
  default = null
}

# cluster
variable "cluster_name" {
  type    = string
  default = null
}

variable "node_pool_name" {
  type    = string
  default = null
}

variable "node_count" {
  type    = number
  default = null
}

variable "node_machine_type" {
  type    = string
  default = null
}

# artifact registry
variable "docker_repo_name" {
  type    = string
  default = null
}