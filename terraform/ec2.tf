locals {
  instance_names = [
    "k8s-control-plane",
    "k8s-worker1",
    "k8s-worker2",
    "jenkins-server"
  ]
}

resource "aws_instance" "servers" {
  count         = 4
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.devops_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = count.index == 0 ? file("${path.module}/user-data/control-plane.sh") :
              count.index == 3 ? file("${path.module}/user-data/jenkins.sh") :
              file("${path.module}/user-data/worker.sh")

  tags = merge(local.common_tags,{
    Name = local.instance_names[count.index]
    Role = count.index == 0 ? "ControlPlane" :
           count.index == 3 ? "Jenkins" : "Worker"
  })
}
