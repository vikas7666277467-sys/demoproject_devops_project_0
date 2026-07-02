data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "http" "github_meta" {
  url = "https://api.github.com/meta"
  request_headers = {
    Accept     = "application/vnd.github+json"
    User-Agent = "Terraform-demoproject-devops-project2"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = local.selected_az
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "cluster" {
  name_prefix = "${var.project_name}-"
  description = "One project SG: restricted management, public web, and trusted node-to-node traffic"
  vpc_id      = aws_vpc.main.id

  # SSH administration. Prefer SSM Session Manager; SSH remains for the requested teaching workflow.
  ingress {
    description = "SSH administration from trusted CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # Browser traffic for future reverse proxies or ingress controllers.
  ingress {
    description = "HTTP web traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.web_cidr_blocks
  }

  ingress {
    description = "HTTPS web traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.web_cidr_blocks
  }

  # Jenkins administration from trusted networks.
  ingress {
    description = "Jenkins UI from trusted CIDRs"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # GitHub publishes and updates these hook source ranges through its Meta API.
  ingress {
    description      = "GitHub webhook delivery from published hook CIDRs"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = local.github_hook_ipv4
    ipv6_cidr_blocks = local.github_hook_ipv6
  }

  # kubectl talks to kube-apiserver on 6443.
  ingress {
    description = "Kubernetes API from administrators and Jenkins"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # Optional direct Prometheus and Grafana NodePort/UI access for training.
  ingress {
    description = "Prometheus UI from trusted CIDRs"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "Grafana UI from trusted CIDRs"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "Prometheus NodePort from trusted CIDRs"
    from_port   = 30090
    to_port     = 30090
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "Grafana NodePort from trusted CIDRs"
    from_port   = 30300
    to_port     = 30300
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    description = "Application NodePort from web clients"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = var.web_cidr_blocks
  }

  # This self rule covers etcd 2379-2380, kubelet 10250, controller-manager
  # 10257, scheduler 10259, NodePorts 30000-32767, Calico, and all other
  # intra-cluster traffic without exposing those ports to the Internet.
  ingress {
    description = "All node-to-node cluster communication (SG self-reference)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Package, registry, GitHub, DockerHub, and AWS API access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-sg" }
}

resource "aws_iam_role" "ec2" {
  name_prefix = "${var.project_name}-ec2-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
  tags = { Name = "${var.project_name}-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${var.project_name}-"
  role        = aws_iam_role.ec2.name
}

resource "aws_instance" "server" {
  for_each = local.instances

  ami                         = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type               = each.value.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  monitoring                  = true
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    hostname           = each.key
    role               = each.value.role
    kubernetes_version = var.kubernetes_version
    ssh_public_key     = var.allowed_ssh_public_key == null ? "" : var.allowed_ssh_public_key
  })

  tags = {
    Name = each.key
    Role = each.value.role
  }

  depends_on = [aws_route_table_association.public]
}
