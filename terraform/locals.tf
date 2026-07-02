locals {
  selected_az = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])
  github_hook_cidrs = try(jsondecode(data.http.github_meta.response_body).hooks, [])
  github_hook_ipv4  = [for cidr in local.github_hook_cidrs : cidr if !strcontains(cidr, ":")]
  github_hook_ipv6  = [for cidr in local.github_hook_cidrs : cidr if strcontains(cidr, ":")]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "demoproject_devops_project2"
  }

  instances = {
    k8s-control-plane = {
      role          = "control-plane"
      instance_type = var.instance_types.control_plane
    }
    k8s-worker1 = {
      role          = "worker"
      instance_type = var.instance_types.worker
    }
    k8s-worker2 = {
      role          = "worker"
      instance_type = var.instance_types.worker
    }
    jenkins-server = {
      role          = "jenkins"
      instance_type = var.instance_types.jenkins
    }
  }
}
