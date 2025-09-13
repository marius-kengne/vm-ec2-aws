
# AMI Ubuntu 22.04 (amd64) via SSM
data "aws_ami" "ubuntu_jammy" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


# VPC
data "aws_vpc" "default" { default = true }


# Security Group (ouvre 22 et 80 ; egress all)
resource "aws_security_group" "sg" {
  name        = "${var.ec2_instance_name}-sg"
  description = "SG for ${var.ec2_instance_name}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# Clé SSH (RSA 2048) + local save (.pem)
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${var.private_key_path}/${var.private_key_name}.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "kp" {
  key_name   = "${var.ec2_instance_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# Instance EC2 
resource "aws_instance" "ec2" {
  ami                         = data.aws_ami.ubuntu_jammy.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.sg.id]
  key_name                    = aws_key_pair.kp.key_name
  associate_public_ip_address = true

  tags = { Name = var.ec2_instance_name }
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
      "docker --version || true",

            # Deploy Jenkins
      "echo '****************** Deploy Jenkins compose ******************'",
      "sudo mkdir -p /opt/jenkins-compose",
      "sudo git clone https://github.com/marius-kengne/jenkins-docker-compose.git /opt/jenkins-compose || (cd /opt/jenkins-compose && sudo git pull)",
      "sudo docker compose -f /opt/jenkins-compose/docker-compose.yaml up -d",
      "sudo docker ps -a",

    ]
  }
}
