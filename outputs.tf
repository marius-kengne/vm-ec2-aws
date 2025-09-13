output "eip" {
  value = aws_eip.eip.public_ip
}

output "ssh_command" {
  value = "ssh -i ${pathexpand("${var.private_key_path}${var.private_key_name}.pem")} -o IdentitiesOnly=yes ubuntu@${aws_eip.eip.public_ip}"
}

output "private_key_path" {
  value     = pathexpand(var.private_key_path)
  sensitive = true
}
