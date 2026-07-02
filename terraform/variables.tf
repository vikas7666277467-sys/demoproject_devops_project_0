variable "aws_region" {
  description = "AWS region in which the lab is created."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name applied to resources and tags."
  type        = string
  default     = "demoproject-devops-project2"
}

variable "environment" {
  description = "Deployment environment tag."
  type        = string
  default     = "training"
}

variable "vpc_cidr" {
  description = "CIDR range for the project VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR range for the single public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "Optional AZ; null selects the first available AZ."
  type        = string
  default     = null
  nullable    = true
}

variable "admin_cidr_blocks" {
  description = "Trusted public CIDRs allowed to reach SSH, Jenkins, Kubernetes API, and dashboards. Never use 0.0.0.0/0 in production."
  type        = list(string)

  validation {
    condition     = length(var.admin_cidr_blocks) > 0
    error_message = "Provide at least one trusted administrator CIDR."
  }
}

variable "web_cidr_blocks" {
  description = "CIDRs allowed to reach public HTTP/HTTPS and the application NodePort."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "key_name" {
  description = "Existing EC2 key-pair name. Set null when Session Manager is the only access method."
  type        = string
  default     = null
  nullable    = true
}

variable "instance_types" {
  description = "EC2 instance type by node role. Monitoring workloads need more memory on workers."
  type        = map(string)
  default = {
    control_plane = "t3.medium"
    worker        = "t3.large"
    jenkins       = "t3.medium"
  }
}

variable "root_volume_size" {
  description = "Encrypted gp3 root volume size in GiB."
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 20
    error_message = "root_volume_size must be at least 20 GiB."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes RPM repository minor version."
  type        = string
  default     = "1.36"
}

variable "allowed_ssh_public_key" {
  description = "Optional SSH public key installed by cloud-init in addition to an EC2 key pair."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}
