#!/bin/bash
# Mirantis Internship 2018
# Task 10-12.1
# Eugeniy Khvastunov
# Deployment of two VM.
#
apt-get update
echo "Install Libvirt, QEMU and some additional tools..."
apt-get install cpu-checker libvirt-bin qemu-kvm libvirt-bin virtinst bridge-utils genisoimage -y
#
echo "Step 0: Reading variables from config..."
SCRPATH="$(/bin/readlink -f "$0" | rev | cut -c 15- | rev)"
CONFIGFILE=$SCRPATH'config'
echo "Config file: $CONFIGFILE"
set -o allexport
source $CONFIGFILE
set +o allexport
#Normalization
#EXTERNAL_IF=$(echo $EXTERNAL_IF | tr -d \'\"\”,)
#INTERNAL_IF=$(echo $INTERNAL_IF | tr -d \'\"\”,)
#MANAGEMENT_IF=$(echo $MANAGEMENT_IF | tr -d \'\"\”,)
echo "===CONFIG START===
SCRPATH: $SCRPATH
CONFIGFILE: $CONFIGFILE
# Libvirt networks
# external network parameters
EXTERNAL_NET_NAME: $EXTERNAL_NET_NAME
EXTERNAL_NET_TYPE: $EXTERNAL_NET_TYPE
EXTERNAL_NET: $EXTERNAL_NET
EXTERNAL_NET_IP: $EXTERNAL_NET_IP
EXTERNAL_NET_MASK: $EXTERNAL_NET_MASK
EXTERNAL_NET_HOST_IP: $EXTERNAL_NET_HOST_IP
VM1_EXTERNAL_IP: $VM1_EXTERNAL_IP

# internal network parameters
INTERNAL_NET_NAME: $INTERNAL_NET_NAME
INTERNAL_NET: $INTERNAL_NET
INTERNAL_NET_IP: $INTERNAL_NET_IP
INTERNAL_NET_MASK: $INTERNAL_NET_MASK

# management network parameters
MANAGEMENT_NET_NAME: $MANAGEMENT_NET_NAME
MANAGEMENT_NET: $MANAGEMENT_NET
MANAGEMENT_NET_IP: $MANAGEMENT_NET_IP
MANAGEMENT_NET_MASK: $MANAGEMENT_NET_MASK
MANAGEMENT_HOST_IP: $MANAGEMENT_HOST_IP

# VMs global parameters
SSH_PUB_KEY: $SSH_PUB_KEY
VM_TYPE: $VM_TYPE
VM_VIRT_TYPE: $VM_VIRT_TYPE
VM_DNS: $VM_DNS
VM_BASE_IMAGE: $VM_BASE_IMAGE

# overlay
VXLAN_NET: $VXLAN_NET
VID: $VID
VXLAN_IF: $VXLAN_IF

# VMs
VM1_NAME: $VM1_NAME
VM1_NUM_CPU: $VM1_NUM_CPU
VM1_MB_RAM: $VM1_MB_RAM
VM1_HDD: $VM1_HDD
VM1_CONFIG_ISO: $VM1_CONFIG_ISO
VM1_EXTERNAL_IF: $VM1_EXTERNAL_IF
VM1_INTERNAL_IF: $VM1_INTERNAL_IF
VM1_MANAGEMENT_IF: $VM1_MANAGEMENT_IF
VM1_INTERNAL_IP: $VM1_INTERNAL_IP
VM1_MANAGEMENT_IP: $VM1_MANAGEMENT_IP
VM1_VXLAN_IP: $VM1_VXLAN_IP

VM2_NAME: $VM2_NAME
VM2_NUM_CPU: $VM2_NUM_CPU
VM2_MB_RAM: $VM2_MB_RAM
VM2_HDD: $VM2_HDD
VM2_CONFIG_ISO: $VM2_CONFIG_ISO
VM2_INTERNAL_IF: $VM2_INTERNAL_IF
VM2_MANAGEMENT_IF: $VM2_MANAGEMENT_IF
VM2_INTERNAL_IP: $VM2_INTERNAL_IP
VM2_MANAGEMENT_IP: $VM2_MANAGEMENT_IP
VM2_VXLAN_IP: $VM2_VXLAN_IP
===CONFIG END==="

echo "Creating all necessary directories:"
mkdir -vp config-drives/$VM1_NAME-config
mkdir -vp config-drives/$VM2_NAME-config
mkdir -vp networks
mkdir -vp /var/lib/libvirt/images/$VM1_NAME
mkdir -vp /var/lib/libvirt/images/$VM2_NAME

echo "Deleting base image..."
rm -v /var/lib/libvirt/images/xenial-server-cloudimg-amd64-disk1.img

echo "Downloading base image:"
wget -O /var/lib/libvirt/images/xenial-server-cloudimg-amd64-disk1.img $VM_BASE_IMAGE

echo "Copying from base image to VMs HDD:"
cp -v /var/lib/libvirt/images/xenial-server-cloudimg-amd64-disk1.img $VM1_HDD
cp -v /var/lib/libvirt/images/xenial-server-cloudimg-amd64-disk1.img $VM2_HDD

echo "Generate MAC adress for VM1 external network"
VM1_EXTERNAL_MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
echo "VM1_EXTERNAL_MAC: $VM1_EXTERNAL_MAC"

echo "Check if SSH key exists"
if [ -e $SSH_PUB_KEY ]
then 
	echo "SSH key exists"
else
	echo "SSH key doesn't exists"
        exit 1
fi
