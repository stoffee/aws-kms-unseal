output "connections" {
  value = <<VAULT
Connect to Vault via SSH   ssh ubuntu@${aws_instance.vault[0].public_ip} -i private.key
Vault web interface  http://${aws_instance.vault[0].public_ip}:8200/ui
VAULT

}