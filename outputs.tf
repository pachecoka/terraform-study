output "get_credentials" {
  description = "get credentials command"
  value       = format("gcloud container clusters get-credentials --project %s --region %s --internal-ip %s",
    "reactive-study-337414", "us-east1", "reactive-study-cluster")
}

output "bastion_ssh_background" {
  description = "gcloud compute ssh to the bastion host command"
  value       = format("gcloud compute ssh %s --project %s --zone %s -- -t -L8888:127.0.0.1:8888 -f tail -f /dev/null",
    google_compute_instance.bastion.name, "reactive-study-337414", google_compute_instance.bastion.zone)
}

output "bastion_kubectl" {
  description = "kubectl command using the local proxy once the bastion_ssh command is running"
  value       = "HTTPS_PROXY=localhost:8888 kubectl get pods --all-namespaces"
}