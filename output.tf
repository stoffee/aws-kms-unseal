output "proddb_db_instance_address" {
  description = "The address of the PRODDB RDS instance"
  value       = "${aws_db_instance.proddb.address}"
}

output "vault_db_instance_address" {
  description = "The address of the VAULT RDS instance"
  value       = "${aws_db_instance.vault.address}"
}

output "connections" {
  value = <<VAULT
Connect to Vault via SSH   ssh -i private.key ubuntu@${aws_instance.vault[0].public_ip}
Connect to SSH Host        ssh -i private.key ubuntu@${aws_instance.ssh[0].public_ip}
Vault web interface  http://${aws_instance.vault[0].public_ip}:8200/ui
NGINX web interface  https://${aws_instance.vault[0].public_ip}
VAULT
}

output "ssh" {
  value = <<SSH
----

----
On the SSH host do this:
sudo curl -o /etc/ssh/trusted-user-ca-keys.pem http://${aws_instance.vault[0].public_ip}:8200/v1/ssh-client-signer/public_key  
or
sudo su -
VAULT_ADDR=http://${aws_instance.vault[0].public_ip}:8200 vault read -field=public_key ssh-client-signer/config/ca > /etc/ssh/trusted-user-ca-keys.pem

----
Update the sshd_config:
# /etc/ssh/sshd_config
# ...
TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem
---
Restart sshd: sudo systemctl restart sshd

----
Do this on the vault server:
---
create a sshkey:
ssh-keygen -t rsa -C "ubuntu"

----
Ask Vault to sign the public key:
vault write ssh-client-signer/sign/my-role \
    public_key=@$HOME/.ssh/id_rsa.pub

----
Save the signed key to disk:
vault write -field=signed_key ssh-client-signer/sign/my-role \
    public_key=@$HOME/.ssh/id_rsa.pub > signed-cert.pub

----
Now ssh to the client host:
ssh -i signed-cert.pub -i ~/.ssh/id_rsa ubuntu@${aws_instance.ssh[0].public_ip}
SSH
}