#!/usr/bin/env bash

apt update
apt-get install -y unzip nginx jq postgresql-client-common
# apt-get install -y libtool libltdl-dev 

USER="vault"
COMMENT="Hashicorp vault user"
GROUP="vault"
HOME="/opt/vault"

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


chmod 0664 /lib/systemd/system/vault.service
systemctl daemon-reload
chown -R vault:vault /etc/vault.d
chmod -R 0644 /etc/vault.d/*

cat << EOF > /etc/profile.d/vault.sh
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
EOF

source /etc/profile.d/vault.sh

systemctl enable vault
systemctl start vault

sleep 10

mkdir -p /opt/vault/setup
touch /opt/vault/setup/vault.unseal.info /opt/vault/setup/bootstrap_config.log
ln -s /usr/local/bin/vault /usr/bin/vault

vault operator init -recovery-shares=1 -recovery-threshold=1 >> /opt/vault/setup/vault.unseal.info
ROOT_TOKEN=`cat /opt/vault/setup/vault.unseal.info |grep Root|awk '{print $4}'`
vault login $ROOT_TOKEN >> /opt/vault/setup/bootstrap_config.log
vault secrets enable transit >> /opt/vault/setup/bootstrap_config.log
vault secrets enable -path=encryption transit >> /opt/vault/setup/bootstrap_config.log
vault write -f transit/keys/orders >> /opt/vault/setup/bootstrap_config.log


wget https://releases.hashicorp.com/consul-template/0.22.0/consul-template_0.22.0_linux_amd64.tgz >> /opt/vault/setup/bootstrap_config.log
tar zxvf consul-template_0.22.0_linux_amd64.tgz >> /opt/vault/setup/bootstrap_config.log
mv consul-template /usr/local/bin/ >> /opt/vault/setup/bootstrap_config.log
ln -s /usr/local/bin/consul-template /usr/bin/consul-template >> /opt/vault/setup/bootstrap_config.log

vault secrets enable pki >> /opt/vault/setup/bootstrap_config.log
vault write -format=json pki/root/generate/internal common_name="pki-ca-root" ttl=87600h | tee  >(jq -r .data.certificate > ca.pem)  >(jq -r .data.issuing_ca > issuing_ca.pem) >(jq -r .data.private_key > ca-key.pem) >> /opt/vault/setup/bootstrap_config.log
curl -s http://localhost:8200/v1/pki/ca/pem | openssl x509 -text >> /opt/vault/setup/bootstrap_config.log

vault secrets enable -path pki_int pki >> /opt/vault/setup/bootstrap_config.log
vault write -format=json pki_int/intermediate/generate/internal common_name="pki-ca-int" ttl=43800h | tee >(jq -r .data.csr > pki_int.csr) >(jq -r .data.private_key > pki_int.pem) >> /opt/vault/setup/bootstrap_config.log
vault write -format=json pki/root/sign-intermediate csr=@pki_int.csr common_name="pki-ca-int" ttl=43800h | tee >(jq -r .data.certificate > pki_int.pem) >(jq -r .data.issuing_ca > pki_int_issuing_ca.pem) >> /opt/vault/setup/bootstrap_config.log
vault write pki_int/intermediate/set-signed certificate=@pki_int.pem >> /opt/vault/setup/bootstrap_config.log
vault write pki_int/roles/stoffee-dot-io allow_any_name=true max_ttl="2m" generate_lease=true >> /opt/vault/setup/bootstrap_config.log

cat << EOF > /opt/vault/setup/pki_int.hcl
path "pki_int/issue/*" {
      capabilities = ["create", "update"]
    }
    path "pki_int/certs" {
      capabilities = ["list"]
    }
    path "pki_int/revoke" {
      capabilities = ["create", "update"]
    }
    path "pki_int/tidy" {
      capabilities = ["create", "update"]
    }
    path "pki/cert/ca" {
      capabilities = ["read"]
    }
    path "auth/token/renew" {
      capabilities = ["update"]
    }
    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
EOF

vault policy write pki_int /opt/vault/setup/pki_int.hcl >> /opt/vault/setup/bootstrap_config.log
vault write pki_int/config/urls issuing_certificates="http://127.0.0.1:8200/v1/pki_int/ca" crl_distribution_points="http://127.0.0.1:8200/v1/pki_int/crl" >> /opt/vault/setup/bootstrap_config.log

cat << EOF > /opt/vault/setup/expiration.json
{ "expiry": "2m" }
EOF

curl --header "X-Vault-Token: $ROOT_TOKEN" --request POST --data @/opt/vault/setup/expiration.json http://127.0.0.1:8200/v1/pki_int/config/crl >> /opt/vault/setup/bootstrap_config.log

vault token create -policy=pki_int -ttl=24h >> /opt/vault/setup/consul-template-token
CT_TOKEN=`sed -n 3p /opt/vault/setup/consul-template-token | awk '{print $2}'`

vault write pki_int/issue/stoffee-dot-io common_name=stoffee.io >> /opt/vault/setup/bootstrap_config.log

mkdir /etc/consul-template.d/ >> /opt/vault/setup/bootstrap_config.log
cat << EOF > /etc/consul-template.d/pki-demo.hcl
vault {
  address = "http://127.0.0.1:8200"
  renew_token = true
  token = "$CT_TOKEN"
  retry {
    enabled = true
    attempts = 5
    backoff = "250ms"
  }
}
template {
  source      = "/etc/consul-template.d/yet-cert.tpl"
  destination = "/etc/nginx/certs/yet.crt"
  perms       = "0600"
  command     = "systemctl reload nginx"
}
template {
  source      = "/etc/consul-template.d/yet-key.tpl"
  destination = "/etc/nginx/certs/yet.key"
  perms       = "0600"
  command     = "systemctl reload nginx"
}
EOF

mkdir -p /etc/nginx/certs >> /opt/vault/setup/bootstrap_config.log

cat << EOF > /etc/consul-template.d/yet-cert.tpl
{{- /* yet-cert.tpl */ -}}
{{ with secret "pki_int/issue/stoffee-dot-io" "common_name=stoffee.io"     "ttl=2m" }}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}{{ end }}
EOF

cat << EOF > /etc/consul-template.d/yet-key.tpl
{{- /* yet-cert.tpl */ -}}
{{ with secret "pki_int/issue/stoffee-dot-io" "common_name=stoffee.io"     "ttl=2m" }} 
{{ .Data.private_key }}{{ end }}
EOF

cat << EOF > /etc/systemd/system/consul-template.service
[Unit]
Description=consul-template
Requires=network-online.target
After=network-online.target


[Service]
EnvironmentFile=-/etc/sysconfig/consul-template
Restart=on-failure
ExecStart=/usr/local/bin/consul-template $OPTIONS -config='/etc/consul-template.d/pki-demo.hcl'
KillSignal=SIGINT
ExecReload=/bin/kill --signal HUP
KillMode=process
Restart=on-failure
RestartSec=5


[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload >> /opt/vault/setup/bootstrap_config.log
sudo systemctl enable consul-template.service >> /opt/vault/setup/bootstrap_config.log
sudo systemctl start consul-template.service >> /opt/vault/setup/bootstrap_config.log
sudo systemctl status consul-template.service >> /opt/vault/setup/bootstrap_config.log

mkdir -p /etc/nginx/sites-available >> /opt/vault/setup/bootstrap_config.log
cat << EOF > /etc/nginx/sites-available/pki-demo
# redirect traffic from http to https.
server {
listen              80;
listen              [::]:80;
server_name         stoffee.io www.stoffee.io;
return 301          https://stoffee.io$request_uri;
return 301          https://www.stoffee.io$request_uri;
}


server {
    listen              443 ssl http2 default_server;
    server_name         stoffee.io www.stoffee.io;
    ssl_certificate     /etc/nginx/certs/yet.crt;
    ssl_certificate_key /etc/nginx/certs/yet.key;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         HIGH:!aNULL:!MD5;


    location / {
      root   /usr/share/nginx/html;
      index  index.html index.htm;
    }
}
EOF

ln -s /etc/nginx/sites-available/pki-demo /etc/nginx/sites-enabled/pki-demo >> /opt/vault/setup/bootstrap_config.log
rm /etc/nginx/sites-enabled/default >> /opt/vault/setup/bootstrap_config.log
sleep 10
systemctl restart nginx >> /opt/vault/setup/bootstrap_config.log
systemctl status nginx >> /opt/vault/setup/bootstrap_config.log



##
###
#####
## configure postgres ##
#####
###
##

#DB_ADDRESS=$TF_VAR_db_address
echo "the OUTPUT of the DB_ADDRESS is ${db_address}" >> /opt/vault/setup/bootstrap_config.log

vault login $ROOT_TOKEN

vault secrets enable database
echo "vault write database/config/proddb \
    plugin_name=postgresql-database-plugin \
    allowed_roles=\"admin-role\" \
    connection_url=\"postgresql://{{username}}:{{password}}@${db_address}:5432/proddb\" \
    username=\"dbaccount\" \
    password=\"4me2know\" " >> /opt/vault/setup/bootstrap_config.log
vault write database/config/proddb \
    plugin_name=postgresql-database-plugin \
    allowed_roles="admin-role" \
    connection_url="postgresql://{{username}}:{{password}}@${db_address}:5432/proddb" \
    username="dbaccount" \
    password="4me2know" >> /opt/vault/setup/bootstrap_config.log

vault write database/roles/admin-role \
    db_name=proddb \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h" >> /opt/vault/setup/bootstrap_config.log
# call this with vault read database/creds/admin-role
echo "vault read database/creds/admin-role" >> /opt/vault/setup/admin-role-db
vault read database/creds/admin-role 2>>/opt/vault/setup/bootstrap_config.log 1>> /opt/vault/setup/admin-role-db
vault write -force database/rotate-root/proddb 2>>/opt/vault/setup/bootstrap_config.log 1>> /opt/vault/setup/admin-role-db



##
###
#####
## Configure Transit Secrets Engine ##
#####
###
##

vault secrets enable transit >>/opt/vault/setup/bootstrap_config.log
vault secrets enable -path=encryption transit >>/opt/vault/setup/bootstrap_config.log
vault write -f transit/keys/orders >>/opt/vault/setup/bootstrap_config.log
vault write transit/encrypt/orders plaintext=$(base64 <<< "4111 1111 1111 1111") >> /opt/vault/setup/plaintext
vault write transit/decrypt/orders \
        ciphertext="vault:v1:cZNHVx+sxdMErXRSuDa1q/pz49fXTn1PScKfhf+PIZPvy8xKfkytpwKcbC0fF2U=" >> /opt/vault/setup/ciphertext
echo "base64 --decode <<< \"Y3JlZGl0LWNhcmQtbnVtYmVyCg==\"" >>  /opt/vault/setup/ciphertext
base64 --decode <<< "Y3JlZGl0LWNhcmQtbnVtYmVyCg==" >>  /opt/vault/setup/ciphertext


echo "All Done"  >> /opt/vault/setup/bootstrap_config.log





shutdown -r now