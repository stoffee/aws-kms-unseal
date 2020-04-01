# Hashicorp Vault on AWS Demo
## Vault Auto-unseal using AWS KMS 
## RDS MYSQL database permissions 
## Vault CA backed SSH

This repo contains a file storage based Vault single server in AWS.<br>
            **_ THIS IS NOT FOR PRODUCTION _**
* Deply Vault with Auto Uneal 
* * https://www.vaultproject.io/docs/concepts/seal/
* Deploy Vault Database Secrets Engine to manage Postgres RDS instances
* * https://www.vaultproject.io/docs/secrets/databases/postgresql/
* Database Root Credential Password Rotation with Vault
* * https://learn.hashicorp.com/vault/secrets-management/db-root-rotation

---

### Setup

1. Set this location as your working directory
1. Set your AWS credentials as environment variables: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
1. Set option variables by renaming `terraform.tfvars.example` to `terraform.tfvars` and edit the values to your needs.
1. Grab the latest version of [Terraform https://www.terraform.io/downloads.html] (https://www.terraform.io/downloads.html)

### Deployment Commands

#### Pull necessary plugins
$ `terraform init`

#### Run the terraform plan
$ `terraform plan`

#### Output provides the SSH instruction
$ `terraform apply`
#
### Connect to the servers
#### Connect to the vault, ssh, and bastion servers
* Look in the terraform output for the server ssh info<br>
$ `ssh -i private.key ubuntu@<IP_ADDRESS>`

#### Once logged in to any instance
$ `vault status`

#### Check out the vault credentials and unseal key on the Vault server
$ `cat /opt/vault/setup/vault.unseal.info`

#### Login on any server with the root token from above
$ `vault login <INITIAL_ROOT_TOKEN>`
#
## NGINX Certs Demo
 Run the scipt `/opt/vault/nginx_demo.sh`
#
## Postgres Demo
$ `vault login <INITIAL_ROOT_TOKEN>`<br>
$ `vault read database/creds/admin-role`<br>
$ `psql -h <YOUR_AMAZON_PUBILC_DNS> -d proddb -U`<br>
```sql
USERNAME -W
SELECT u.usename AS "Role name",
  CASE WHEN u.usesuper AND u.usecreatedb THEN CAST('superuser, create
database' AS pg_catalog.text)
       WHEN u.usesuper THEN CAST('superuser' AS pg_catalog.text)
       WHEN u.usecreatedb THEN CAST('create database' AS
pg_catalog.text)
       ELSE CAST('' AS pg_catalog.text)
  END AS "Attributes"
FROM pg_catalog.pg_user u
ORDER BY 1;
```
#
## Transit Engine Demo
$ `vault login`<br>
$ `vault write transit/encrypt/orders plaintext=$(base64 <<< "4111 1111 1111 1111")`<br>
$ `vault write transit/decrypt/orders ciphertext=“CIPHER"`<br>
$ `base64 -d <<< <RESULTOFABOVE>`
#
## SSH Demo
#### On the SSH host and the bastion host do one of these:
$ `sudo curl -o /etc/ssh/trusted-user-ca-keys.pem http://54.176.94.52:8200/v1/ssh-client-signer/public_key`<br>
or<br>
$ `sudo su -`
$ `VAULT_ADDR=http://54.176.94.52:8200 vault read -field=public_key ssh-client-signer/config/ca > /etc/ssh/trusted-user-ca-keys.pem`<br>
#
#### Update the sshd_config on both SSH and Bastion host:
$ `sudo vi /etc/ssh/sshd_config`
```
# ...
TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem
```
#
#### Restart sshd
$ `sudo systemctl restart sshd`
#
### Do this on the vault server:
#### create a sshkey:
$ `ssh-keygen -t rsa -C "ubuntu"`
#
#### Ask Vault to sign the public key:
$ `vault login`<br>
$ `vault write ssh-client-signer/sign/my-role public_key=@$HOME/.ssh/id_rsa.pub`
#
#### Save the signed key to disk:
$ `vault write -field=signed_key ssh-client-signer/sign/my-role public_key=@$HOME/.ssh/id_rsa.pub > signed-cert.pub`
#
### Now ssh to the client host:
$ `ssh -i signed-cert.pub -i ~/.ssh/id_rsa ubuntu@13.57.195.23`

### now that we can connect to the host, we want to connnect through the bastion
**_ THIS IS IN THE OUTPUT OF TERRAFORM _**
#### Add this to vault server ~vault/.ssh/ssh_config
```
Host bastion
  Hostname <BASTION_HOST>
  IdentityFile ~/.ssh/id_rsa
  CertificateFile ~/.ssh/signed-cert.pub
  User ubuntu
Host <SSH_HOST>
  IdentityFile ~/.ssh/id_rsa
  ProxyCommand ssh -F uname bastion nc %h %p
  User ubuntu
```
----
## Now let's try to connect:
$ `ssh -i signed-cert.pub -i ~/.ssh/id_rsa ubuntu@<YOUR_AWS_HOST>`

# Clean up...
$ `terraform destroy -force`<br>
$ `rm -rf .terraform terraform.tfstate*`
