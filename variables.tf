variable "app_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ec2_instance_name" {
  description = "Nom/prefix des ressources"
  type        = string
  default     = "vm-ec2"
}

variable "instance_type" {
  description = "Type EC2 (amd64)"
  type        = string
  default     = "t3.micro"
}

variable "private_key_path" {
  description = "Chemin local du .pem à écrire"
  type        = string
  default     = "~/.ssh/cicd_ec2.pem"
}

variable "private_key_name" {
  description = "name of file that content private key"
  type        = string
  default     = "vm-ec2"
}