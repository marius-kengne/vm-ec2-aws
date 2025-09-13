variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "name" {
  description = "Nom/prefix des ressources"
  type        = string
  default     = "cicd-ec2-docker"
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
