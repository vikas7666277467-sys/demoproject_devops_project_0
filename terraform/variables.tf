variable "aws_region" {
  description = "AWS Region"
  type = string
  default = "eu-central-1"
}

variable "project_name" {
  description = "Project Name"
  type = string
  default = "demoproject"
}

variable "environment" {
  description = "Environment"
  type = string
  default = "Lab"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type = string
  default = "t3.medium"
}

variable "key_name" {
  description = "AWS Key Pair"
  type = string
}

variable "root_volume_size" {
  description = "Root Volume Size"
  type = number
  default = 30
}

variable "allowed_ssh_ip" {
  description = "Laptop Public IP"
  type = string
  default = "0.0.0.0/0"
}
