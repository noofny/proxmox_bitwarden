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
