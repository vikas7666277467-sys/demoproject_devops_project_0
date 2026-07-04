output "control_plane_public_ip" {
  value = aws_instance.servers[0].public_ip
}

output "worker1_public_ip" {
  value = aws_instance.servers[1].public_ip
}

output "worker2_public_ip" {
  value = aws_instance.servers[2].public_ip
}

output "jenkins_public_ip" {
  value = aws_instance.servers[3].public_ip
}

output "security_group_id" {
  value = aws_security_group.devops_sg.id
}

output "instance_ids" {
  value = aws_instance.servers[*].id
}
