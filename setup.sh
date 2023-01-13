#!/bin/bash -e


# functions
function error() {
    echo -e "\e[91m[ERROR] $1\e[39m"
}
function warn() {
    echo -e "\e[93m[WARNING] $1\e[39m"
}
function info() {
    echo -e "\e[36m[INFO] $1\e[39m"
}
function cleanup() {
    popd >/dev/null
    rm -rf $TEMP_FOLDER_PATH
}


echo "###########################"
echo "Setup : begin"
echo "###########################"


TEMP_FOLDER_PATH=$(mktemp -d)
pushd $TEMP_FOLDER_PATH >/dev/null


# prompts/args
DEFAULT_HOSTNAME='vault-1'
DEFAULT_PASSWORD='bitwarden'
DEFAULT_IPV4_CIDR='192.168.0.25/24'
DEFAULT_IPV4_GW='192.168.0.1'
DEFAULT_NET_INTERFACE='eth0'
DEFAULT_NET_BRIDGE='vmbr1'
DEFAULT_CONTAINER_ID=$(pvesh get /cluster/nextid)
read -p "Enter a hostname (${DEFAULT_HOSTNAME}) : " HOSTNAME
read -s -p "Enter a password (${DEFAULT_PASSWORD}) : " HOSTPASS
echo -e "\n"
read -p "Enter an IPv4 CIDR (${DEFAULT_IPV4_CIDR}) : " HOST_IP4_CIDR
read -p "Enter an IPv4 Gateway (${DEFAULT_IPV4_GW}) : " HOST_IP4_GATEWAY
read -p "Enter the network interface to use (${DEFAULT_NET_INTERFACE}) : " NET_INTERFACE
read -p "Enter the network bridge to use (${DEFAULT_NET_BRIDGE}) : " NET_BRIDGE
read -p "Enter a container ID (${DEFAULT_CONTAINER_ID}) : " CONTAINER_ID
read -p "Enter your email address : " EMAIL_ADDRESS
read -p "Enter your domain name : " DOMAIN_NAME
HOSTNAME="${HOSTNAME:-${DEFAULT_HOSTNAME}}"
HOSTPASS="${HOSTPASS:-${DEFAULT_PASSWORD}}"
HOST_IP4_CIDR="${HOST_IP4_CIDR:-${DEFAULT_IPV4_CIDR}}"
HOST_IP4_GATEWAY="${HOST_IP4_GATEWAY:-${DEFAULT_IPV4_GW}}"
NET_INTERFACE="${NET_INTERFACE:-${DEFAULT_NET_INTERFACE}}"
NET_BRIDGE="${NET_BRIDGE:-${DEFAULT_NET_BRIDGE}}"
CONTAINER_ID="${CONTAINER_ID:-${DEFAULT_CONTAINER_ID}}"
export HOST_IP4_CIDR=${HOST_IP4_CIDR}
export EMAIL_ADDRESS=${EMAIL_ADDRESS}
export DOMAIN_NAME=${DOMAIN_NAME}
# NOTE: Use 'pveam' tool to list available & download LXC images.
#       Path for 'remote' storage will be '/mnt/proxmox/template/cache/'
# TODO: make this dynamic so the user can choose!
CONTAINER_OS_TYPE='ubuntu'
CONTAINER_OS_VERSION='ubuntu-22.04-standard_22.04-1_amd64.tar.zst'
TEMPLATE_LOCATION="remote:vztmpl/${CONTAINER_OS_VERSION}"
info "Using template: ${TEMPLATE_LOCATION}"


# storage location
STORAGE_LIST=( $(pvesm status -content rootdir | awk 'NR>1 {print $1}') )
if [ ${#STORAGE_LIST[@]} -eq 0 ]; then
    warn "'Container' needs to be selected for at least one storage location."
    die "Unable to detect valid storage location."
elif [ ${#STORAGE_LIST[@]} -eq 1 ]; then
    STORAGE=${STORAGE_LIST[0]}
else
    info "More than one storage locations detected."
    PS3=$"Which storage location would you like to use? "
    select storage_item in "${STORAGE_LIST[@]}"; do
        if [[ " ${STORAGE_LIST[*]} " =~ ${storage_item} ]]; then
            STORAGE=$storage_item
            break
        fi
        echo -en "\e[1A\e[K\e[1A"
    done
fi
info "Using '$STORAGE' for storage location."


# Create the container
info "Creating LXC container..."
CONTAINER_ARCH=$(dpkg --print-architecture)
info "Using ARCH: ${CONTAINER_ARCH}"
pct create "${CONTAINER_ID}" "${TEMPLATE_LOCATION}" \
    -arch "${CONTAINER_ARCH}" \
    -cores 2 \
    -memory 4096 \
    -swap 4096 \
    -onboot 1 \
    -features nesting=1 \
    -hostname "${HOSTNAME}" \
    -net0 name=${NET_INTERFACE},bridge=${NET_BRIDGE},gw=${HOST_IP4_GATEWAY},ip=${HOST_IP4_CIDR} \
    -ostype "${CONTAINER_OS_TYPE}" \
    -password ${HOSTPASS} \
    -storage "${STORAGE}"


# Configure container
info "Configuring LXC container..."
pct resize "${CONTAINER_ID}" rootfs 50G


# Start container
info "Starting LXC container..."
pct start "${CONTAINER_ID}"
sleep 5
CONTAINER_STATUS=$(pct status $CONTAINER_ID)
if [ ${CONTAINER_STATUS} != "status: running" ]; then
    error "Container ${CONTAINER_ID} is not running! status=${CONTAINER_STATUS}"
    exit 1
fi


# Setup OS
info "Fetching setup script..."
wget -qL https://raw.githubusercontent.com/noofny/proxmox_bitwarden/master/setup_os.sh
info "Executing script..."
pct push "${CONTAINER_ID}" ./setup_os.sh /setup_os.sh -perms 755
pct exec "${CONTAINER_ID}" -- bash -c "/setup_os.sh"
pct reboot "${CONTAINER_ID}"


# Setup docker
info "Fetching setup script..."
wget -qL https://raw.githubusercontent.com/noofny/proxmox_bitwarden/master/setup_docker.sh
info "Executing script..."
cat ./setup_docker.sh
pct push "${CONTAINER_ID}" ./setup_docker.sh /setup_docker.sh -perms 755
pct exec "${CONTAINER_ID}" -- bash -c "/setup_docker.sh"
pct reboot "${CONTAINER_ID}"


# Setup Bitwarden
info "Fetching setup script..."
wget -qL https://raw.githubusercontent.com/noofny/proxmox_bitwarden/master/setup_bitwarden.sh
info "Executing script..."
pct push "${CONTAINER_ID}" ./setup_bitwarden.sh /setup_bitwarden.sh -perms 755
pct exec "${CONTAINER_ID}" -- bash -c "/setup_bitwarden.sh"


# Done - reboot!
rm -rf ${TEMP_FOLDER_PATH}
info "Container and app setup - container will restart!"
pct reboot "${CONTAINER_ID}"


echo "###########################"
echo "Setup : complete"
echo "###########################"
