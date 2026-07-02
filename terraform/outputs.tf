output "public_ips" {
  description = "Public IPv4 address keyed by server name."
  value       = { for name, instance in aws_instance.server : name => instance.public_ip }
}

output "private_ips" {
  description = "Private IPv4 address keyed by server name."
  value       = { for name, instance in aws_instance.server : name => instance.private_ip }
}

output "jenkins_url" {
  description = "Jenkins initial setup URL."
  value       = "http://${aws_instance.server["jenkins-server"].public_ip}:8080"
}

output "control_plane_ip" {
  description = "Control-plane public and private addresses."
  value = {
    public  = aws_instance.server["k8s-control-plane"].public_ip
    private = aws_instance.server["k8s-control-plane"].private_ip
  }
}

output "worker_ips" {
  description = "Worker public and private addresses."
  value = {
    for name in ["k8s-worker1", "k8s-worker2"] : name => {
      public  = aws_instance.server[name].public_ip
      private = aws_instance.server[name].private_ip
    }
  }
}

output "application_url" {
  description = "Application URL after Kubernetes deployment."
  value       = "http://${aws_instance.server["k8s-worker1"].public_ip}:30080"
}

output "ssm_session_commands" {
  description = "Session Manager commands that avoid opening SSH."
  value       = { for name, instance in aws_instance.server : name => "aws ssm start-session --target ${instance.id} --region ${var.aws_region}" }
}

