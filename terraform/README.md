# Terraform Infrastructure

## Overview
This Terraform project provisions:
- 1 Kubernetes Control Plane
- 2 Kubernetes Worker Nodes
- 1 Jenkins Server
- 1 Security Group
- Default VPC/Subnet

# Terraform Directory Structure

This project follows a **production-style Terraform repository structure**, where each Terraform file has a specific responsibility. Splitting the infrastructure into multiple files makes the project easier to understand, maintain, troubleshoot, and scale.

---

# Directory Structure

```text
terraform/
├── README.md
├── versions.tf
├── provider.tf
├── variables.tf
├── terraform.tfvars.example
├── locals.tf
├── data.tf
├── networking.tf
├── security_group.tf
├── ec2.tf
├── outputs.tf
└── user-data/
    ├── control-plane.sh
    ├── worker.sh
    └── jenkins.sh
```

---


### Purpose

This file contains the complete documentation for the Terraform files

### It includes

- Project overview
- Architecture
- Prerequisites
- Usage instructions
- Terraform commands
- Resources created
- Directory structure
- Troubleshooting
- Best practices

### Why do we need it?

---

# versions.tf

### Purpose

Defines the Terraform version and Provider version required by the project.

Example

```hcl
terraform {
  required_version = ">=1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.50"
    }
  }
}
```

### Why do we need it?

Ensures every team member uses compatible versions of Terraform and the AWS Provider.

Without this file:

- Different Terraform versions may behave differently.
- Provider compatibility issues can occur.

---

# provider.tf

### Purpose

Configures the AWS Provider.

Example

```hcl
provider "aws" {
    region = var.aws_region
}
```

### What does it do?

It tells Terraform:

- Which cloud provider to use
- Which AWS Region to deploy resources into
- Which credentials to use (AWS CLI, IAM Role, or environment variables)

### In this project

Resources will be created in:

```
eu-central-1
```

---

# variables.tf

### Purpose

Defines all input variables used throughout the project.

Example

```hcl
variable "instance_type" {
    default = "t3.medium"
}
```

### What does it do?

Instead of hardcoding values inside Terraform code, variables make the project reusable.

Example variables

- AWS Region
- Instance Type
- Key Pair
- Environment
- Project Name
- Root Volume Size

### Benefits

- Easy customization
- Reusable code
- Cleaner Terraform configuration

---

# terraform.tfvars.example

### Purpose

Provides example values for the variables.

Example

```hcl
instance_type = "t3.medium"

key_name = "demo-key"
```

### Why do we need it?

Instead of editing Terraform code, users simply create:

```
terraform.tfvars
```

and provide their own values.

This makes the project portable.

---

# locals.tf

### Purpose

Stores local variables used across the project.

Example

```hcl
locals {

    common_tags = {

        Project = "DevOps"

        Environment = "Lab"

    }

}
```

### What does it do?

Creates reusable values.

Instead of writing the same tags repeatedly:

```hcl
tags = {

Project="DevOps"

Environment="Lab"

}
```

We simply use

```hcl
tags = local.common_tags
```

### Benefits

- Less duplication
- Easier maintenance
- Cleaner code

---

# data.tf

### Purpose

Looks up existing AWS resources.

Terraform creates new resources using **resource** blocks.

Terraform reads existing resources using **data** blocks.

### Examples

Lookup

- Default VPC
- Default Subnets
- Latest Amazon Linux AMI

Example

```hcl
data "aws_vpc" "default" {

default = true

}
```

### Why?

Instead of hardcoding

```
vpc-123456
```

Terraform automatically discovers the correct VPC.

This makes the project portable across AWS accounts.

---

# networking.tf

### Purpose

Contains networking-related resources.

Examples

- VPC
- Subnets
- Internet Gateway
- Route Tables
- NAT Gateway

### In this project

We are using the AWS Default VPC.

Therefore, this file currently only references the networking configuration.

Later, if we migrate to a custom VPC, all networking resources can be added here.

### Benefits

Keeps networking separate from compute resources.

---

# security_group.tf

### Purpose

Creates the Security Group used by all EC2 instances.

### It configures

SSH

```
22
```

HTTP

```
80
```

HTTPS

```
443
```

Jenkins

```
8080
```

Kubernetes API

```
6443
```

NodePort

```
30000-32767
```

Prometheus

```
9090
```

Grafana

```
3000
```

Alertmanager

```
9093
```

Kubelet

```
10250
```

Scheduler

```
10259
```

Controller Manager

```
10257
```

etcd

```
2379-2380
```

### Why separate file?

Security Groups often change independently from EC2 instances.

Keeping them separate makes management easier.

---

# ec2.tf

### Purpose

Creates all EC2 instances.

This is the core infrastructure file.

### It provisions

```
1 Kubernetes Control Plane

2 Kubernetes Worker Nodes

1 Jenkins Server
```

Each instance receives

- AMI
- Instance Type
- Key Pair
- Security Group
- Root Volume
- Public IP
- Tags
- User Data

### Why separate file?

Infrastructure grows over time.

Keeping EC2 resources separate improves readability.

---

# outputs.tf

### Purpose

Displays useful information after Terraform finishes.

Example

```bash
terraform apply
```

Output

```
Control Plane Public IP

Worker1 Public IP

Worker2 Public IP

Jenkins Public IP
```

### Benefits

No need to open the AWS Console to find the server IP addresses.

Useful for

- SSH
- Jenkins Access
- Kubernetes Access

---

# user-data/

The **user-data** directory contains startup scripts that are automatically executed when an EC2 instance boots for the first time.

Terraform passes these scripts to the EC2 instances using the **user_data** argument.

This allows the servers to perform initial configuration automatically.

---

## control-plane.sh

### Purpose

Prepares the Kubernetes Control Plane server.

### Tasks performed

- Update operating system
- Disable swap
- Configure kernel modules
- Configure networking
- Install containerd
- Enable required services

This server will later become the Kubernetes Master Node.

---

## worker.sh

### Purpose

Prepares Kubernetes Worker Nodes.

### Tasks performed

- Update operating system
- Disable swap
- Configure networking
- Install containerd
- Enable required services

Later, these servers will join the Kubernetes cluster.

---

## jenkins.sh

### Purpose

Prepares the Jenkins Server.

### Tasks performed

- Update operating system
- Install Java
- Install Docker
- Install Git
- Configure Docker service

Later in the project, Jenkins itself will be installed and configured manually.

---

# Why Split Terraform into Multiple Files?

Instead of writing everything inside one large **main.tf**, we organize the project into logical files.

## Advantages

- Easy to read
- Easy to troubleshoot
- Easy to maintain
- Easier collaboration among team members
- Easier to reuse components
- Follows industry best practices
- Matches enterprise DevOps project standards

---

# Terraform Workflow

```text
versions.tf
        │
        ▼
provider.tf
        │
        ▼
variables.tf
        │
        ▼
terraform.tfvars
        │
        ▼
locals.tf
        │
        ▼
data.tf
        │
        ▼
networking.tf
        │
        ▼
security_group.tf
        │
        ▼
ec2.tf
        │
        ▼
user-data Scripts
        │
        ▼
AWS Infrastructure Created
        │
        ▼
outputs.tf
        │
        ▼
Display Public IPs & Resource Information
```

---

# Summary

| File | Purpose |
|-------|---------|
| README.md | Project documentation and usage guide |
| versions.tf | Defines Terraform and AWS provider versions |
| provider.tf | Configures the AWS provider and region |
| variables.tf | Declares reusable input variables |
| terraform.tfvars.example | Sample variable values for users |
| locals.tf | Stores reusable local values such as tags |
| data.tf | Retrieves existing AWS resources (VPC, Subnets, AMI) |
| networking.tf | Contains networking configuration and future VPC resources |
| security_group.tf | Creates the Security Group and firewall rules |
| ec2.tf | Provisions the EC2 instances |
| outputs.tf | Displays important resource information after deployment |
| user-data/control-plane.sh | Bootstraps the Kubernetes Control Plane server |
| user-data/worker.sh | Bootstraps Kubernetes Worker Nodes |
| user-data/jenkins.sh | Bootstraps the Jenkins Server |

---



After understanding this directory structure, you will be able to:

- Organize Terraform projects using industry-standard practices.
- Understand the purpose of each Terraform configuration file.
- Separate infrastructure into logical components.
- Build reusable and maintainable Infrastructure as Code (IaC).
- Easily extend the project by adding new resources without affecting existing code.
