#!/usr/bin/env bash

apt-get install -y unzip
# apt-get install -y libtool libltdl-dev 

USER="vault"
COMMENT="Hashicorp vault user"
GROUP="vault"
HOME="/srv/vault"

# Detect package management system.
YUM=$(which yum 2>/dev/null)
APT_GET=$(which apt-get 2>/dev/null)

user_rhel() {
  # RHEL user setup
  sudo /usr/sbin/groupadd --force --system $${GROUP}

  if ! getent passwd $${USER} >/dev/null ; then
    sudo /usr/sbin/adduser \
      --system \
      --gid $${GROUP} \
      --home $${HOME} \
      --no-create-home \
      --comment "$${COMMENT}" \
      --shell /bin/false \
      $${USER}  >/dev/null
  fi
}

user_ubuntu() {
  # UBUNTU user setup
  if ! getent group $${GROUP} >/dev/null
  then
    sudo addgroup --system $${GROUP} >/dev/null
  fi

  if ! getent passwd $${USER} >/dev/null
  then
    sudo adduser \
      --system \
      --disabled-login \
      --ingroup $${GROUP} \
      --home $${HOME} \
      --no-create-home \
      --gecos "$${COMMENT}" \
      --shell /bin/false \
      $${USER}  >/dev/null
  fi
}

if [[ ! -z $${YUM} ]]; then
  logger "Setting up user $${USER} for RHEL/CentOS"
  user_rhel
elif [[ ! -z $${APT_GET} ]]; then
  logger "Setting up user $${USER} for Debian/Ubuntu"
  user_ubuntu
else
  logger "$${USER} user not created due to OS detection failure"
  exit 1;
fi

logger "User setup complete"



VAULT_ZIP="vault.zip"
VAULT_URL="${vault_url}"
curl --silent --output /tmp/$${VAULT_ZIP} $${VAULT_URL}
unzip -o /tmp/$${VAULT_ZIP} -d /usr/local/bin/
chmod 0755 /usr/local/bin/vault
chown vault:vault /usr/local/bin/vault
mkdir -pm 0755 /etc/vault.d
mkdir -pm 0755 /opt/vault
chown vault:vault /opt/vault


cat << EOF > /lib/systemd/system/vault.service
[Unit]
Description=Vault Agent
Requires=network-online.target
After=network-online.target
[Service]
Restart=on-failure
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /usr/local/bin/vault
ExecStart=/usr/local/bin/vault server -config /etc/vault.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=vault
Group=vault
[Install]
WantedBy=multi-user.target
EOF


cat << EOF > /etc/vault.d/vault.hcl
storage "file" {
  path = "/opt/vault"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
seal "awskms" {
  region     = "${aws_region}"
  kms_key_id = "${kms_key}"
}
ui=true
EOF


sudo chmod 0664 /lib/systemd/system/vault.service
systemctl daemon-reload
sudo chown -R vault:vault /etc/vault.d
sudo chmod -R 0644 /etc/vault.d/*

cat << EOF > /etc/profile.d/vault.sh
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
EOF

source /etc/profile.d/vault.sh

systemctl enable vault
systemctl start vault

sleep 10

sudo touch /opt/vault/vault.unseal.info /opt/vault/setup.log
sudo chmod 777 /opt/vault/vault.unseal.info /opt/vault/setup.log
sudo ln -s /usr/local/bin/vault /usr/bin/vault

vault operator init -recovery-shares=1 -recovery-threshold=1 >> /opt/vault/vault.unseal.info
ROOT_TOKEN=`cat /opt/vault/vault.unseal.info |grep Root|awk '{print $4}'`
vault login $ROOT_TOKEN >> /opt/vault/setup.log
vault secrets enable transit >> /opt/vault/setup.log
vault secrets enable -path=encryption transit >> /opt/vault/setup.log
vault vault write -f transit/keys/orders >> /opt/vault/setup.log


sudo apt -y install nginx
wget https://releases.hashicorp.com/consul-template/0.22.0/consul-template_0.22.0_linux_amd64.tgz
tar zxvf consul-template_0.22.0_linux_amd64.tgz
sudo mv consul-template /usr/local/bin/
sudo ln -s /usr/local/bin/consul-template /usr/bin/consul-template

vault secrets enable pki
vault write -format=json pki/root/generate/internal common_name="pki-ca-root" ttl=87600h | tee  >(jq -r .data.certificate > ca.pem)  >(jq -r .data.issuing_ca > issuing_ca.pem) >(jq -r .data.private_key > ca-key.pem)
curl -s http://localhost:8200/v1/pki/ca/pem | openssl x509 -text

vault secrets enable -path pki_int pki
vault write -format=json pki_int/intermediate/generate/internal common_name="pki-ca-int" ttl=43800h | tee >(jq -r .data.csr > pki_int.csr) >(jq -r .data.private_key > pki_int.pem)
vault write -format=json pki/root/sign-intermediate csr=@pki_int.csr common_name="pki-ca-int" ttl=43800h | tee >(jq -r .data.certificate > pki_int.pem) >(jq -r .data.issuing_ca > pki_int_issuing_ca.pem)
vault write pki_int/intermediate/set-signed certificate=@pki_int.pem
vault write pki_int/roles/stoffee-dot-io allow_any_name=true max_ttl="2m" generate_lease=true

