#!/bin/bash -e


echo "###########################"
echo "Setup Bitwarden : begin"
echo "###########################"


# locale
echo "Setting locale..."
LOCALE_VALUE="en_AU.UTF-8"
echo ">>> locale-gen..."
locale-gen ${LOCALE_VALUE}
cat /etc/default/locale
source /etc/default/locale
echo ">>> update-locale..."
update-locale ${LOCALE_VALUE}
echo ">>> hack /etc/ssh/ssh_config..."
sed -e '/SendEnv/ s/^#*/#/' -i /etc/ssh/ssh_config


echo "Installing Bitwarden..."
usermod -aG docker root
usermod -aG docker vaultadmin
sudo mkdir /opt/bitwarden
sudo chmod -R 700 /opt/bitwarden
curl -Lso bitwarden.sh https://go.btwrdn.co/bw-sh && chmod 700 bitwarden.sh
./bitwarden.sh install


echo "Configuring certs..."
curl https://get.acme.sh | sh
echo "# Enter/uncomment your cloud provider API key below..." >> /root/.acme.sh/account.conf
echo "SAVED_CF_Key='YOUR_CLOUD_PROVIDER_API_KEY'" >> /root/.acme.sh/account.conf
echo "SAVED_CF_Email='${EMAIL_ADDRESS}'" >> /root/.acme.sh/account.conf
nano /root/.acme.sh/account.conf
CURRENT_DIR=$(pwd)
cd /root/.acme.sh
# NOTE: 'register' often requires a few retries...
#   Could not get nonce, let's try again.
#   Could not get nonce, let's try again.
#   Could not get nonce, let's try again.
#   ...etc...
./acme.sh --register-account -m "${EMAIL_ADDRESS}"
./acme.sh --issue --dns dns_cf --dnssleep 20 -d "${DOMAIN_NAME}"
# NOTE: 'issue' often requires a bit of waiting...
# Processing, The CA is processing your order, please just wait. (1/30)
# Processing, The CA is processing your order, please just wait. (2/30)
# Processing, The CA is processing your order, please just wait. (3/30)
#   ...etc...
mv /root/.acme.sh/${DOMAIN_NAME}/${DOMAIN_NAME}.cer /bwdata/ssl/${DOMAIN_NAME}/certificate.cer
mv /root/.acme.sh/${DOMAIN_NAME}/${DOMAIN_NAME}.key /bwdata/ssl/${DOMAIN_NAME}/private.key
mv /root/.acme.sh/${DOMAIN_NAME}/ca.cer /bwdata/ssl/${DOMAIN_NAME}/ca.cer
mv /root/.acme.sh/${DOMAIN_NAME}/fullchain.cer /bwdata/ssl/${DOMAIN_NAME}/fullchain.cer
sed -e 's/certificate.crt/certificate.cer/' -i /bwdata/config.yml
sed -e 's/ca.crt/ca.cer/' -i /bwdata/config.yml
sed -e 's/certificate.crt/certificate.cer/' -i /bwdata/nginx/default.conf
sed -e 's/ca.crt/ca.cer/' -i /bwdata/nginx/default.conf
sed -e 's/SAVED_CF_Key/# SAVED_CF_Key/' -i /root/.acme.sh/account.conf
cd "${CURRENT_DIR}"


echo "Opening config file(s) for editing..."
nano /bwdata/env/global.override.env


echo "Starting Bitwarden..."
./bitwarden.sh start


echo "Listing Docker containers..."
docker ps


echo "Setup complete - you can access the console at http://$(hostname -I)"


echo "###########################"
echo "Setup Bitwarden : complete"
echo "###########################"
