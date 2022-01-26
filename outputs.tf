output "get_credentials" {
  description = "gcloud get-credentials command"
  value       = format("gcloud container clusters get-credentials --project %s --region %s %s", var.project, var.region, var.cluster_name)
}