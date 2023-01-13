#!/bin/bash -e


echo "###########################"
echo "Setup Docker : begin"
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


echo "Installing dependencies..."
apt install -y \
    apt-transport-https \
    ca-certificates \
    software-properties-common


echo "Installing Docker..."
curl -fsSL download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update &&
apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose
systemctl enable docker


echo "Removing AppArmor..."
apt-get remove -y apparmor


echo "###########################"
echo "Setup Docker : complete"
echo "###########################"
