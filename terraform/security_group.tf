resource "aws_security_group" "devops_sg" {
  name        = "${var.project_name}-sg"
  description = "Security Group for DevOps Demo Project"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [var.allowed_ssh_ip]
  }

  dynamic "ingress" {
    for_each = [
      {from=80,to=80,desc="HTTP"},
      {from=443,to=443,desc="HTTPS"},
      {from=8080,to=8080,desc="Jenkins"},
      {from=6443,to=6443,desc="Kubernetes API"},
      {from=2379,to=2380,desc="etcd"},
      {from=10250,to=10250,desc="Kubelet"},
      {from=10257,to=10257,desc="Controller Manager"},
      {from=10259,to=10259,desc="Scheduler"},
      {from=9090,to=9090,desc="Prometheus"},
      {from=3000,to=3000,desc="Grafana"},
      {from=9093,to=9093,desc="Alertmanager"},
      {from=30000,to=32767,desc="NodePort"}
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags,{
    Name="${var.project_name}-sg"
  })
}
