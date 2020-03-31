resource "aws_instance" "ssh" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.medium"
  count         = 1
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = "cdunlap-aws"

  security_groups = [
    aws_security_group.vault.id,
  ]

  associate_public_ip_address = true
  ebs_optimized               = false
  iam_instance_profile        = aws_iam_instance_profile.vault-kms-unseal.id

  tags = {
    Name = "${var.namespace}-${random_pet.env.id}-ssh"
  }

  user_data = data.template_file.ssh.rendered
}

data "template_file" "ssh" {
  template = file("ssh.tpl")

  vars = {
    vault_url  = var.vault_url
    aws_region = var.aws_region
  }
}

#data "template_file" "format_ssh" {
#  template = "connect to host with following command: ssh ubuntu@$${admin} -i private.key"
#
#  vars = {
#    admin = aws_instance.ssh[0].public_ip
#  }
#}