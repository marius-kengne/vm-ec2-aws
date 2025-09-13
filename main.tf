terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws   = { source = "hashicorp/aws",  version = ">= 5.0" }
    tls   = { source = "hashicorp/tls",  version = ">= 4.0" }
    local = { source = "hashicorp/local", version = ">= 2.0" }
    null  = { source = "hashicorp/null", version = ">= 3.0" }
  }
}

provider "aws" {
  region = var.region
}

# AMI Ubuntu 22.04 (amd64) via SSM – simple et toujours à jour
data "aws_ssm_parameter" "ubuntu_amd64" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# VPC/Subnet par défaut (pas de création)
data "aws_vpc" "default" { default = true }
data "aws_subnets" "default_vpc_subnets" {
  filter { 
        name = "vpc-id" 
        values = [data.aws_vpc.default.id] 
    }

}
locals {
  subnet_id = data.aws_subnets.default_vpc_subnets.ids[0]
}

# Security Group (ouvre 22 et 80 ; egress all)
resource "aws_security_group" "sg" {
  name        = "${var.name}-sg"
  description = "SG for ${var.name}"
  vpc_id      = data.aws_vpc.default.id

  ingress { from_port = 22 to_port = 22 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0  to_port = 0  protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

# Clé SSH (RSA 2048) + enregistrement local (.pem)
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = pathexpand(var.private_key_path)
  file_permission = "0600"
}

resource "aws_key_pair" "kp" {
  key_name   = "${var.name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# Instance EC2 
resource "aws_instance" "ec2" {
  ami                         = data.aws_ssm_parameter.ubuntu_amd64.value
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  key_name                    = aws_key_pair.kp.key_name
  associate_public_ip_address = true

  tags = { Name = var.name }
}

# Elastic IP (EIP)
resource "aws_eip" "eip" {
  domain   = "vpc"
  instance = aws_instance.ec2.id
}

# Install docker
resource "null_resource" "provision_docker" {
  depends_on = [aws_eip.eip]

  connection {
    type        = "ssh"
    host        = aws_eip.eip.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.ssh.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "sudo apt-get update -y",
      "curl -fsSL https://get.docker.com | sudo sh",
      "sudo usermod -aG docker ubuntu || true",
      "sudo systemctl enable docker && sudo systemctl start docker",
      "docker --version || true"
    ]
  }
}
