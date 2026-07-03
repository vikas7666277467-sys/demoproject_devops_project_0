# Part 2 - AWS Infrastructure Setup

In this section, we will provision the complete AWS infrastructure required for this project using Terraform.

The infrastructure consists of four Amazon EC2 instances that will later be configured manually as a Kubernetes cluster and a Jenkins server.

---

# Infrastructure Overview

The infrastructure consists of the following EC2 instances.

| Server | Hostname | Purpose |
|---------|----------|----------|
| EC2-1 | k8s-control-plane | Kubernetes Control Plane |
| EC2-2 | k8s-worker1 | Kubernetes Worker Node 1 |
| EC2-3 | k8s-worker2 | Kubernetes Worker Node 2 |
| EC2-4 | jenkins-server | Jenkins CI/CD Server |

All servers will be created automatically using Terraform.

---

# AWS Architecture

```text
                           AWS Cloud
                                │
                                ▼
                     Default AWS VPC
                                │
               ┌────────────────────────────────┐
               │                                │
               │      Single Security Group     │
               │                                │
               └────────────────────────────────┘
                                │
        ┌───────────────┬───────────────┬───────────────┬───────────────┐
        ▼               ▼               ▼               ▼
+----------------+ +---------------+ +---------------+ +---------------+
| Control Plane  | | Worker Node 1 | | Worker Node 2 | | Jenkins Server|
+----------------+ +---------------+ +---------------+ +---------------+
```

---

# Why Four Servers?

Each server has a dedicated responsibility.

## Kubernetes Control Plane

Responsible for managing the Kubernetes cluster.

Runs

- API Server
- Scheduler
- Controller Manager
- etcd

---

## Worker Node 1

Runs application workloads.

Example

- Flask Application
- Monitoring Components
- Other Kubernetes Pods

---

## Worker Node 2

Provides High Availability.

Runs

- Application Pods
- Monitoring Pods
- Rolling Updates

---

## Jenkins Server

Responsible for

- Continuous Integration
- Continuous Deployment
- Docker Build
- Docker Push
- Kubernetes Deployment

---

# AWS Prerequisites

Before creating the infrastructure, ensure the following prerequisites are completed.

## AWS Account

Create an AWS Account if you do not already have one.

https://aws.amazon.com/

---

## IAM User

Create an IAM User with AdministratorAccess for learning purposes.

Configure the AWS CLI using this IAM User.

---

## Install AWS CLI

Verify installation

```bash
aws --version
```

---

## Configure AWS CLI

```bash
aws configure
```

Provide

```
AWS Access Key

AWS Secret Key

Region

Output Format
```

Example

```
Region

eu-central-1

Output

json
```

Verify

```bash
aws sts get-caller-identity
```

Expected Output

```json
{
    "Account": "123456789012",
    "UserId": "AIDAXXXXX",
    "Arn": "arn:aws:iam::123456789012:user/admin"
}
```

---

# Create an EC2 Key Pair

Open

AWS Console

↓

EC2

↓

Key Pairs

↓

Create Key Pair

Name

```
demo-key
```

Download

```
demo-key.pem
```

Keep this file safe.

It will be used to connect to all EC2 instances.

---

# Default VPC

This project uses the existing AWS Default VPC.

Verify

AWS Console

↓

VPC

↓

Your VPCs

Locate

```
Default VPC
```

No additional networking configuration is required.

---

# Security Group

Terraform will create a single Security Group.

All EC2 instances will use this Security Group.

The following ports should be allowed.

| Port | Protocol | Purpose |
|------|----------|----------|
|22|TCP|SSH|
|80|TCP|HTTP|
|443|TCP|HTTPS|
|6443|TCP|Kubernetes API|
|2379-2380|TCP|etcd|
|10250|TCP|Kubelet|
|10257|TCP|Controller Manager|
|10259|TCP|Scheduler|
|30000-32767|TCP|NodePort Services|
|8080|TCP|Jenkins|
|9090|TCP|Prometheus|
|3000|TCP|Grafana|

---

## Self Referencing Rule

The Security Group should allow communication with itself.

Purpose

- Control Plane ↔ Worker Nodes
- Worker 1 ↔ Worker 2
- Kubernetes Internal Traffic
- Calico Networking
- kube-proxy
- etcd Communication

This rule is mandatory for kubeadm clusters.

---

# Instance Specifications

For this lab, use the following EC2 configuration.

| Property | Value |
|----------|-------|
|AMI|Amazon Linux 2023|
|Instance Type|t3.medium|
|Volume|20 GB gp3|
|Architecture|x86_64|
|VPC|Default|
|Subnet|Default|
|Security Group|Terraform Created|
|Key Pair|demo-key|

---

# Recommended Instance Types

| Server | Recommended |
|---------|-------------|
|Control Plane|t3.medium|
|Worker Node 1|t3.medium|
|Worker Node 2|t3.medium|
|Jenkins|t3.medium|

Minimum

```
2 vCPU

4 GB RAM
```

---

# Folder Structure

Create the following directory.

```text
demoproject_devops_project2/
│
├── terraform/
│   ├── provider.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── README.md
```

---

# Verify Prerequisites

Before moving to the Terraform configuration, verify the following.

✅ AWS CLI Installed

```bash
aws --version
```

---

✅ AWS CLI Configured

```bash
aws sts get-caller-identity
```

---

✅ Terraform Installed

```bash
terraform version
```

---

✅ Git Installed

```bash
git --version
```

---

✅ SSH Available

```bash
ssh -V
```

---

# Next Section

# Part 2B - Writing the Terraform Configuration

In this section, we will create the complete Terraform configuration required to provision the AWS infrastructure.

Terraform will automatically create:

- 4 EC2 Instances
- 1 Security Group
- Security Group Rules
- EC2 Tags
- Outputs

The infrastructure created in this step will be used throughout the remainder of this project.

---

# Terraform Directory Structure

Inside the project directory, create the following structure.

```text
demoproject_devops_project2/
│
├── terraform/
│   ├── provider.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── README.md
```

---

# provider.tf

Purpose

This file tells Terraform which cloud provider to use.

Example

```terraform
provider "aws" {
  region = var.aws_region
}
```

Explanation

- Configures AWS as the cloud provider
- Reads the AWS region from variables.tf
- Uses AWS CLI credentials configured on your local machine

---

# versions.tf

Purpose

Locks the Terraform and Provider versions.

Example

```terraform
terraform {

  required_version = ">= 1.5"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }

}
```

Benefits

- Prevents compatibility issues
- Ensures consistent deployments
- Makes the project portable

---

# variables.tf

Purpose

Stores reusable variables.

Example Variables

```terraform
variable "aws_region" {
  default = "eu-central-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {}

variable "project_name" {
  default = "demoproject"
}
```

Recommended Variables

| Variable | Purpose |
|----------|----------|
| aws_region | AWS Region |
| instance_type | EC2 Instance Type |
| key_name | SSH Key Pair |
| project_name | Resource Naming |
| volume_size | Root Volume Size |
| ami_id | Amazon Linux AMI |

---

# terraform.tfvars.example

Purpose

Stores user-specific values.

Example

```terraform
aws_region="eu-central-1"

instance_type="t3.medium"

key_name="demo-key"

project_name="demoproject"

volume_size=20
```

Users should copy this file as

```text
terraform.tfvars
```

and update values if required.

---

# locals.tf

Purpose

Stores reusable local values.

Example

```terraform
locals {

  common_tags = {

    Project = "DevOps Demo"

    Environment = "Lab"

    Owner = "DevOps"

  }

}
```

Advantages

- Reusable values
- Cleaner Terraform code
- Easier maintenance

---

# main.tf

This is the primary Terraform file.

It should create the following resources.

---

## Security Group

Terraform should create a Security Group named

```text
demoproject-sg
```

Required Inbound Rules

| Port | Purpose |
|------|----------|
|22|SSH|
|80|HTTP|
|443|HTTPS|
|6443|Kubernetes API|
|2379-2380|etcd|
|10250|Kubelet|
|10257|Controller Manager|
|10259|Scheduler|
|30000-32767|NodePort|
|8080|Jenkins|
|9090|Prometheus|
|3000|Grafana|

Also create

Self Referencing Rule

Purpose

Allow communication between all EC2 instances.

---

## EC2 Instance 1

Name

```text
k8s-control-plane
```

Purpose

Kubernetes Master

Tags

```text
Name = k8s-control-plane
Role = Kubernetes Master
```

---

## EC2 Instance 2

Name

```text
k8s-worker1
```

Purpose

Worker Node

Tags

```text
Name = k8s-worker1
Role = Kubernetes Worker
```

---

## EC2 Instance 3

Name

```text
k8s-worker2
```

Purpose

Worker Node

Tags

```text
Name = k8s-worker2
Role = Kubernetes Worker
```

---

## EC2 Instance 4

Name

```text
jenkins-server
```

Purpose

Jenkins

Tags

```text
Name = jenkins-server
Role = Jenkins
```

---

# Root Volume

Configure

- gp3 Storage
- 20 GB
- Delete on Termination = true

---

# Instance Metadata

Enable

- IMDSv2

Reason

Improves EC2 Security.

---

# Common Tags

Every resource should include

```text
Project = DevOps Demo

Environment = Lab

ManagedBy = Terraform

CreatedBy = Terraform
```

---

# outputs.tf

Purpose

Display important information after deployment.

Outputs should include

Control Plane Public IP

```terraform
output "control_plane_public_ip" {

}
```

Worker 1 Public IP

Worker 2 Public IP

Jenkins Public IP

Control Plane Private IP

Worker Private IPs

Jenkins Private IP

Security Group ID

Instance IDs

---

# Expected Output

After

```bash
terraform apply
```

Terraform should display

```text
Apply complete!

Outputs

Control Plane Public IP

xx.xx.xx.xx

Worker 1 Public IP

xx.xx.xx.xx

Worker 2 Public IP

xx.xx.xx.xx

Jenkins Public IP

xx.xx.xx.xx

Security Group

sg-xxxxxxxx
```

---

# Resource Dependency

Terraform automatically creates resources in the following order.

```text
AWS Provider
      │
      ▼
Security Group
      │
      ▼
EC2 Instances
      │
      ▼
Outputs
```

---

# Best Practices

✔ Use Variables

✔ Use Outputs

✔ Use Locals

✔ Use Common Tags

✔ Never hardcode credentials

✔ Keep terraform.tfvars out of GitHub

✔ Add terraform.tfstate to .gitignore

✔ Use descriptive resource names

✔ Enable IMDSv2

✔ Validate Terraform before deployment

---

# Files Created So Far

At this stage, the Terraform folder should contain:

```text
terraform/

provider.tf

versions.tf

variables.tf

terraform.tfvars.example

locals.tf

main.tf

outputs.tf

README.md
```

---

# Next Section

# Part 2B - Writing the Terraform Configuration

In this section, we will create the complete Terraform configuration required to provision the AWS infrastructure.

Terraform will automatically create:

- 4 EC2 Instances
- 1 Security Group
- Security Group Rules
- EC2 Tags
- Outputs

The infrastructure created in this step will be used throughout the remainder of this project.

---

# Terraform Directory Structure

Inside the project directory, create the following structure.

```text
demoproject_devops_project2/
│
├── terraform/
│   ├── provider.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── README.md
```

---

# provider.tf

Purpose

This file tells Terraform which cloud provider to use.

Example

```terraform
provider "aws" {
  region = var.aws_region
}
```

Explanation

- Configures AWS as the cloud provider
- Reads the AWS region from variables.tf
- Uses AWS CLI credentials configured on your local machine

---

# versions.tf

Purpose

Locks the Terraform and Provider versions.

Example

```terraform
terraform {

  required_version = ">= 1.5"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }

}
```

Benefits

- Prevents compatibility issues
- Ensures consistent deployments
- Makes the project portable

---

# variables.tf

Purpose

Stores reusable variables.

Example Variables

```terraform
variable "aws_region" {
  default = "eu-central-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {}

variable "project_name" {
  default = "demoproject"
}
```

Recommended Variables

| Variable | Purpose |
|----------|----------|
| aws_region | AWS Region |
| instance_type | EC2 Instance Type |
| key_name | SSH Key Pair |
| project_name | Resource Naming |
| volume_size | Root Volume Size |
| ami_id | Amazon Linux AMI |

---

# terraform.tfvars.example

Purpose

Stores user-specific values.

Example

```terraform
aws_region="eu-central-1"

instance_type="t3.medium"

key_name="demo-key"

project_name="demoproject"

volume_size=20
```

Users should copy this file as

```text
terraform.tfvars
```

and update values if required.

---

# locals.tf

Purpose

Stores reusable local values.

Example

```terraform
locals {

  common_tags = {

    Project = "DevOps Demo"

    Environment = "Lab"

    Owner = "DevOps"

  }

}
```

Advantages

- Reusable values
- Cleaner Terraform code
- Easier maintenance

---

# main.tf

This is the primary Terraform file.

It should create the following resources.

---

## Security Group

Terraform should create a Security Group named

```text
demoproject-sg
```

Required Inbound Rules

| Port | Purpose |
|------|----------|
|22|SSH|
|80|HTTP|
|443|HTTPS|
|6443|Kubernetes API|
|2379-2380|etcd|
|10250|Kubelet|
|10257|Controller Manager|
|10259|Scheduler|
|30000-32767|NodePort|
|8080|Jenkins|
|9090|Prometheus|
|3000|Grafana|

Also create

Self Referencing Rule

Purpose

Allow communication between all EC2 instances.

---

## EC2 Instance 1

Name

```text
k8s-control-plane
```

Purpose

Kubernetes Master

Tags

```text
Name = k8s-control-plane
Role = Kubernetes Master
```

---

## EC2 Instance 2

Name

```text
k8s-worker1
```

Purpose

Worker Node

Tags

```text
Name = k8s-worker1
Role = Kubernetes Worker
```

---

## EC2 Instance 3

Name

```text
k8s-worker2
```

Purpose

Worker Node

Tags

```text
Name = k8s-worker2
Role = Kubernetes Worker
```

---

## EC2 Instance 4

Name

```text
jenkins-server
```

Purpose

Jenkins

Tags

```text
Name = jenkins-server
Role = Jenkins
```

---

# Root Volume

Configure

- gp3 Storage
- 20 GB
- Delete on Termination = true

---

# Instance Metadata

Enable

- IMDSv2

Reason

Improves EC2 Security.

---

# Common Tags

Every resource should include

```text
Project = DevOps Demo

Environment = Lab

ManagedBy = Terraform

CreatedBy = Terraform
```

---

# outputs.tf

Purpose

Display important information after deployment.

Outputs should include

Control Plane Public IP

```terraform
output "control_plane_public_ip" {

}
```

Worker 1 Public IP

Worker 2 Public IP

Jenkins Public IP

Control Plane Private IP

Worker Private IPs

Jenkins Private IP

Security Group ID

Instance IDs

---

# Expected Output

After

```bash
terraform apply
```

Terraform should display

```text
Apply complete!

Outputs

Control Plane Public IP

xx.xx.xx.xx

Worker 1 Public IP

xx.xx.xx.xx

Worker 2 Public IP

xx.xx.xx.xx

Jenkins Public IP

xx.xx.xx.xx

Security Group

sg-xxxxxxxx
```

---

# Resource Dependency

Terraform automatically creates resources in the following order.

```text
AWS Provider
      │
      ▼
Security Group
      │
      ▼
EC2 Instances
      │
      ▼
Outputs
```

---

# Best Practices

✔ Use Variables

✔ Use Outputs

✔ Use Locals

✔ Use Common Tags

✔ Never hardcode credentials

✔ Keep terraform.tfvars out of GitHub

✔ Add terraform.tfstate to .gitignore

✔ Use descriptive resource names

✔ Enable IMDSv2

✔ Validate Terraform before deployment

---

# Files Created So Far

At this stage, the Terraform folder should contain:

```text
terraform/

provider.tf

versions.tf

variables.tf

terraform.tfvars.example

locals.tf

main.tf

outputs.tf

README.md
```

---

# Next Section

# Part 2B - Writing the Terraform Configuration

In this section, we will create the complete Terraform configuration required to provision the AWS infrastructure.

Terraform will automatically create:

- 4 EC2 Instances
- 1 Security Group
- Security Group Rules
- EC2 Tags
- Outputs

The infrastructure created in this step will be used throughout the remainder of this project.

---

# Terraform Directory Structure

Inside the project directory, create the following structure.

```text
demoproject_devops_project2/
│
├── terraform/
│   ├── provider.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── README.md
```

---

# provider.tf

Purpose

This file tells Terraform which cloud provider to use.

Example

```terraform
provider "aws" {
  region = var.aws_region
}
```

Explanation

- Configures AWS as the cloud provider
- Reads the AWS region from variables.tf
- Uses AWS CLI credentials configured on your local machine

---

# versions.tf

Purpose

Locks the Terraform and Provider versions.

Example

```terraform
terraform {

  required_version = ">= 1.5"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }

}
```

Benefits

- Prevents compatibility issues
- Ensures consistent deployments
- Makes the project portable

---

# variables.tf

Purpose

Stores reusable variables.

Example Variables

```terraform
variable "aws_region" {
  default = "eu-central-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {}

variable "project_name" {
  default = "demoproject"
}
```

Recommended Variables

| Variable | Purpose |
|----------|----------|
| aws_region | AWS Region |
| instance_type | EC2 Instance Type |
| key_name | SSH Key Pair |
| project_name | Resource Naming |
| volume_size | Root Volume Size |
| ami_id | Amazon Linux AMI |

---

# terraform.tfvars.example

Purpose

Stores user-specific values.

Example

```terraform
aws_region="eu-central-1"

instance_type="t3.medium"

key_name="demo-key"

project_name="demoproject"

volume_size=20
```

Users should copy this file as

```text
terraform.tfvars
```

and update values if required.

---

# locals.tf

Purpose

Stores reusable local values.

Example

```terraform
locals {

  common_tags = {

    Project = "DevOps Demo"

    Environment = "Lab"

    Owner = "DevOps"

  }

}
```

Advantages

- Reusable values
- Cleaner Terraform code
- Easier maintenance

---

# main.tf

This is the primary Terraform file.

It should create the following resources.

---

## Security Group

Terraform should create a Security Group named

```text
demoproject-sg
```

Required Inbound Rules

| Port | Purpose |
|------|----------|
|22|SSH|
|80|HTTP|
|443|HTTPS|
|6443|Kubernetes API|
|2379-2380|etcd|
|10250|Kubelet|
|10257|Controller Manager|
|10259|Scheduler|
|30000-32767|NodePort|
|8080|Jenkins|
|9090|Prometheus|
|3000|Grafana|

Also create

Self Referencing Rule

Purpose

Allow communication between all EC2 instances.

---

## EC2 Instance 1

Name

```text
k8s-control-plane
```

Purpose

Kubernetes Master

Tags

```text
Name = k8s-control-plane
Role = Kubernetes Master
```

---

## EC2 Instance 2

Name

```text
k8s-worker1
```

Purpose

Worker Node

Tags

```text
Name = k8s-worker1
Role = Kubernetes Worker
```

---

## EC2 Instance 3

Name

```text
k8s-worker2
```

Purpose

Worker Node

Tags

```text
Name = k8s-worker2
Role = Kubernetes Worker
```

---

## EC2 Instance 4

Name

```text
jenkins-server
```

Purpose

Jenkins

Tags

```text
Name = jenkins-server
Role = Jenkins
```

---

# Root Volume

Configure

- gp3 Storage
- 20 GB
- Delete on Termination = true

---

# Instance Metadata

Enable

- IMDSv2

Reason

Improves EC2 Security.

---

# Common Tags

Every resource should include

```text
Project = DevOps Demo

Environment = Lab

ManagedBy = Terraform

CreatedBy = Terraform
```

---

# outputs.tf

Purpose

Display important information after deployment.

Outputs should include

Control Plane Public IP

```terraform
output "control_plane_public_ip" {

}
```

Worker 1 Public IP

Worker 2 Public IP

Jenkins Public IP

Control Plane Private IP

Worker Private IPs

Jenkins Private IP

Security Group ID

Instance IDs

---

# Expected Output

After

```bash
terraform apply
```

Terraform should display

```text
Apply complete!

Outputs

Control Plane Public IP

xx.xx.xx.xx

Worker 1 Public IP

xx.xx.xx.xx

Worker 2 Public IP

xx.xx.xx.xx

Jenkins Public IP

xx.xx.xx.xx

Security Group

sg-xxxxxxxx
```

---

# Resource Dependency

Terraform automatically creates resources in the following order.

```text
AWS Provider
      │
      ▼
Security Group
      │
      ▼
EC2 Instances
      │
      ▼
Outputs
```

---

# Best Practices

✔ Use Variables

✔ Use Outputs

✔ Use Locals

✔ Use Common Tags

✔ Never hardcode credentials

✔ Keep terraform.tfvars out of GitHub

✔ Add terraform.tfstate to .gitignore

✔ Use descriptive resource names

✔ Enable IMDSv2

✔ Validate Terraform before deployment

---

# Files Created So Far

At this stage, the Terraform folder should contain:

```text
terraform/

provider.tf

versions.tf

variables.tf

terraform.tfvars.example

locals.tf

main.tf

outputs.tf

README.md
```

---

# Next Section

# Part 2B - Writing the Terraform Configuration

In this section, we will create the complete Terraform configuration required to provision the AWS infrastructure.

Terraform will automatically create:

- 4 EC2 Instances
- 1 Security Group
- Security Group Rules
- EC2 Tags
- Outputs

The infrastructure created in this step will be used throughout the remainder of this project.

---

# Terraform Directory Structure

Inside the project directory, create the following structure.

```text
demoproject_devops_project2/
│
├── terraform/
│   ├── provider.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── README.md
```

---

# provider.tf

Purpose

This file tells Terraform which cloud provider to use.

Example

```terraform
provider "aws" {
  region = var.aws_region
}
```

Explanation

- Configures AWS as the cloud provider
- Reads the AWS region from variables.tf
- Uses AWS CLI credentials configured on your local machine

---

# versions.tf

Purpose

Locks the Terraform and Provider versions.

Example

```terraform
terraform {

  required_version = ">= 1.5"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }

}
```

Benefits

- Prevents compatibility issues
- Ensures consistent deployments
- Makes the project portable

---

# variables.tf

Purpose

Stores reusable variables.

Example Variables

```terraform
variable "aws_region" {
  default = "eu-central-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {}

variable "project_name" {
  default = "demoproject"
}
```

Recommended Variables

| Variable | Purpose |
|----------|----------|
| aws_region | AWS Region |
| instance_type | EC2 Instance Type |
| key_name | SSH Key Pair |
| project_name | Resource Naming |
| volume_size | Root Volume Size |
| ami_id | Amazon Linux AMI |

---

# terraform.tfvars.example

Purpose

Stores user-specific values.

Example

```terraform
aws_region="eu-central-1"

instance_type="t3.medium"

key_name="demo-key"

project_name="demoproject"

volume_size=20
```

Users should copy this file as

```text
terraform.tfvars
```

and update values if required.

---

# locals.tf

Purpose

Stores reusable local values.

Example

```terraform
locals {

  common_tags = {

    Project = "DevOps Demo"

    Environment = "Lab"

    Owner = "DevOps"

  }

}
```

Advantages

- Reusable values
- Cleaner Terraform code
- Easier maintenance

---

# main.tf

This is the primary Terraform file.

It should create the following resources.

---

## Security Group

Terraform should create a Security Group named

```text
demoproject-sg
```

Required Inbound Rules

| Port | Purpose |
|------|----------|
|22|SSH|
|80|HTTP|
|443|HTTPS|
|6443|Kubernetes API|
|2379-2380|etcd|
|10250|Kubelet|
|10257|Controller Manager|
|10259|Scheduler|
|30000-32767|NodePort|
|8080|Jenkins|
|9090|Prometheus|
|3000|Grafana|

Also create

Self Referencing Rule

Purpose

Allow communication between all EC2 instances.

---

## EC2 Instance 1

Name

```text
k8s-control-plane
```

Purpose

Kubernetes Master

Tags

```text
Name = k8s-control-plane
Role = Kubernetes Master
```

---

## EC2 Instance 2

Name

```text
k8s-worker1
```

Purpose

Worker Node

Tags

```text
Name = k8s-worker1
Role = Kubernetes Worker
```

---

## EC2 Instance 3

Name

```text
k8s-worker2
```

Purpose

Worker Node

Tags

```text
Name = k8s-worker2
Role = Kubernetes Worker
```

---

## EC2 Instance 4

Name

```text
jenkins-server
```

Purpose

Jenkins

Tags

```text
Name = jenkins-server
Role = Jenkins
```

---

# Root Volume

Configure

- gp3 Storage
- 20 GB
- Delete on Termination = true

---

# Instance Metadata

Enable

- IMDSv2

Reason

Improves EC2 Security.

---

# Common Tags

Every resource should include

```text
Project = DevOps Demo

Environment = Lab

ManagedBy = Terraform

CreatedBy = Terraform
```

---

# outputs.tf

Purpose

Display important information after deployment.

Outputs should include

Control Plane Public IP

```terraform
output "control_plane_public_ip" {

}
```

Worker 1 Public IP

Worker 2 Public IP

Jenkins Public IP

Control Plane Private IP

Worker Private IPs

Jenkins Private IP

Security Group ID

Instance IDs

---

# Expected Output

After

```bash
terraform apply
```

Terraform should display

```text
Apply complete!

Outputs

Control Plane Public IP

xx.xx.xx.xx

Worker 1 Public IP

xx.xx.xx.xx

Worker 2 Public IP

xx.xx.xx.xx

Jenkins Public IP

xx.xx.xx.xx

Security Group

sg-xxxxxxxx
```

---

# Resource Dependency

Terraform automatically creates resources in the following order.

```text
AWS Provider
      │
      ▼
Security Group
      │
      ▼
EC2 Instances
      │
      ▼
Outputs
```

---

# Best Practices

✔ Use Variables

✔ Use Outputs

✔ Use Locals

✔ Use Common Tags

✔ Never hardcode credentials

✔ Keep terraform.tfvars out of GitHub

✔ Add terraform.tfstate to .gitignore

✔ Use descriptive resource names

✔ Enable IMDSv2

✔ Validate Terraform before deployment

---

# Files Created So Far

At this stage, the Terraform folder should contain:

```text
terraform/

provider.tf

versions.tf

variables.tf

terraform.tfvars.example

locals.tf

main.tf

outputs.tf

README.md
```

---

# Next Section  In **Part 2C**

# Part 2C - Provisioning the AWS Infrastructure using Terraform

In this section, we will deploy the complete AWS infrastructure using Terraform.

By the end of this section, you will have:

- 4 EC2 Instances
- 1 Security Group
- Public & Private IP Addresses
- Ready-to-use infrastructure for Kubernetes and Jenkins

---

# Step 1 - Navigate to the Terraform Directory

Open your terminal and move to the Terraform directory.

```bash
cd demoproject_devops_project2/terraform
```

Verify the files.

```bash
ls -l
```

Expected Output

```text
provider.tf
versions.tf
variables.tf
terraform.tfvars.example
locals.tf
main.tf
outputs.tf
README.md
```

---

# Step 2 - Configure Variables

Copy the example variable file.

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open the file.

```bash
vi terraform.tfvars
```

Example

```terraform
aws_region    = "eu-central-1"

instance_type = "t3.medium"

key_name      = "demo-key"

project_name  = "demoproject"

volume_size   = 20
```

Save the file.

---

# Step 3 - Initialize Terraform

Initialize the working directory.

```bash
terraform init
```

Expected Output

```text
Initializing the backend...

Initializing provider plugins...

Terraform has been successfully initialized.
```

---

# Step 4 - Format the Code

Terraform provides a built-in formatter.

```bash
terraform fmt
```

This command automatically formats every Terraform file.

---

# Step 5 - Validate the Configuration

Validate the Terraform code.

```bash
terraform validate
```

Expected Output

```text
Success!

The configuration is valid.
```

---

# Step 6 - Create the Execution Plan

Generate a deployment plan.

```bash
terraform plan
```

Terraform will display all resources that will be created.

Example

```text
+ aws_security_group.demoproject_sg

+ aws_instance.k8s-control-plane

+ aws_instance.k8s-worker1

+ aws_instance.k8s-worker2

+ aws_instance.jenkins-server
```

Review the plan carefully before creating resources.

---

# Step 7 - Provision the Infrastructure

Deploy the infrastructure.

```bash
terraform apply
```

Terraform will ask for confirmation.

```text
Do you want to perform these actions?

Enter a value:
```

Type

```text
yes
```

Terraform starts creating resources.

---

# Step 8 - Wait for Completion

Provisioning usually takes 2–5 minutes.

After completion, you should see:

```text
Apply complete!

Resources: 5 added.
```

Terraform displays the outputs.

Example

```text
Control Plane Public IP

18.xx.xx.xx

Worker1 Public IP

18.xx.xx.xx

Worker2 Public IP

18.xx.xx.xx

Jenkins Public IP

18.xx.xx.xx
```

Save these IP addresses.

They will be used throughout the project.

---

# Step 9 - Verify from the AWS Console

Open the AWS Console.

Navigate to

EC2

↓

Instances

Verify that the following instances exist.

| Instance Name | Status |
|---------------|--------|
| k8s-control-plane | Running |
| k8s-worker1 | Running |
| k8s-worker2 | Running |
| jenkins-server | Running |

---

# Step 10 - Verify the Security Group

Open

EC2

↓

Security Groups

Verify the Security Group contains the required inbound rules.

| Port | Purpose |
|------|----------|
|22|SSH|
|80|HTTP|
|443|HTTPS|
|6443|Kubernetes API|
|2379-2380|etcd|
|10250|kubelet|
|10257|Controller Manager|
|10259|Scheduler|
|30000-32767|NodePort|
|8080|Jenkins|
|9090|Prometheus|
|3000|Grafana|

Also verify:

✔ Self-referencing rule

---

# Step 11 - Connect to the Control Plane

```bash
ssh -i demo-key.pem ec2-user@<Control-Plane-Public-IP>
```

Example

```bash
ssh -i demo-key.pem ec2-user@18.192.xx.xx
```

Verify

```bash
hostname
```

Expected

```text
k8s-control-plane
```

Exit

```bash
exit
```

---

# Step 12 - Connect to Worker Node 1

```bash
ssh -i demo-key.pem ec2-user@<Worker1-Public-IP>
```

Verify

```bash
hostname
```

Expected

```text
k8s-worker1
```

Exit

```bash
exit
```

---

# Step 13 - Connect to Worker Node 2

```bash
ssh -i demo-key.pem ec2-user@<Worker2-Public-IP>
```

Verify

```bash
hostname
```

Expected

```text
k8s-worker2
```

Exit

```bash
exit
```

---

# Step 14 - Connect to Jenkins Server

```bash
ssh -i demo-key.pem ec2-user@<Jenkins-Public-IP>
```

Verify

```bash
hostname
```

Expected

```text
jenkins-server
```

Exit

```bash
exit
```

---

# Step 15 - Verify Private Connectivity

SSH into the Control Plane.

```bash
ssh -i demo-key.pem ec2-user@<Control-Plane-IP>
```

Ping Worker Node 1.

```bash
ping <Worker1-Private-IP>
```

Ping Worker Node 2.

```bash
ping <Worker2-Private-IP>
```

Ping Jenkins.

```bash
ping <Jenkins-Private-IP>
```

All hosts should be reachable.

Press

```
Ctrl + C
```

to stop the ping.

---

# Step 16 - Verify AWS Resources Using AWS CLI

List running instances.

```bash
aws ec2 describe-instances \
--query "Reservations[*].Instances[*].[Tags[?Key=='Name']|[0].Value,State.Name,PublicIpAddress]" \
--output table
```

Expected

```text
k8s-control-plane

running

18.xx.xx.xx

k8s-worker1

running

18.xx.xx.xx

k8s-worker2

running

18.xx.xx.xx

jenkins-server

running

18.xx.xx.xx
```

---

# Step 17 - Common Terraform Commands

Initialize

```bash
terraform init
```

Format

```bash
terraform fmt
```

Validate

```bash
terraform validate
```

Plan

```bash
terraform plan
```

Deploy

```bash
terraform apply
```

View Outputs

```bash
terraform output
```

Show Resources

```bash
terraform show
```

List Resources

```bash
terraform state list
```

Destroy Infrastructure

```bash
terraform destroy
```

---

# Common Errors

## Invalid AWS Credentials

Error

```text
No valid credential sources found
```

Solution

```bash
aws configure
```

---

## Key Pair Not Found

Error

```text
InvalidKeyPair.NotFound
```

Solution

Verify the Key Pair name in

```text
terraform.tfvars
```

---

## Security Group Already Exists

Solution

Delete the existing Security Group or rename it in `main.tf`.

---

## AMI Not Found

Solution

Update the AMI ID for your AWS Region.

---

## Terraform State Lock

If Terraform reports a state lock, wait for the previous operation to finish or remove the lock only if you are certain no other Terraform process is running.

---

# Cleanup

After completing the lab, destroy all resources to avoid AWS charges.

```bash
terraform destroy
```

Confirm.

```text
yes
```

Terraform deletes

- EC2 Instances
- Security Group
- Networking Resources created by Terraform

Expected Output

```text
Destroy complete!

Resources: 5 destroyed.
```

---

# Verification Checklist

Before moving to the Kubernetes installation, verify the following:

- Terraform initialized successfully
- Terraform validation passed
- Terraform apply completed successfully
- Four EC2 instances are running
- Security Group contains all required ports
- SSH connectivity works for all servers
- Private network connectivity is verified
- Terraform outputs display all required IP addresses
- AWS Console reflects the created infrastructure

---

# Next Section  In **Part 3**, we will configure the Kubernetes cluster using **kubeadm**.




