output "connections" {
  value = <<VAULT
Connect to Vault via SSH   ssh -i yoursshkey ubuntu@${aws_instance.vault.public_ip} 
Vault web interface  http://${aws_instance.vault.public_ip}:8200/ui
VAULT

}

output "instance_ip_addr" {
  value = aws_instance.vault.private_ip
}