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

echo "Step 1: Inviroment prepearing..."
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

echo "Checking that SSH key exists:"
if [ -e $SSH_PUB_KEY ]
then 
	echo "Key exists, all Ok!"
else
	echo "SSH key doesn't exists, creating it..."
        ssh-keygen -t rsa -b 2048 -C "khvastunov@gmail.com" -f $HOME/.ssh/id_rsa -q N \"\"
fi

echo "Creating external.xml..."
EXTERNAL_NET_XML=$SCRPATH'networks/external.xml'
#---<START: External network template>---
echo"<network>
	<name>${EXTERNAL_NET_NAME}</name>
		<forward mode='nat'>
			<nat>
				<port start='1024' end='65535'/>
			</nat>
		</forward>
	<ip address='$EXTERNAL_NET_HOST_IP' netmask='$EXTERNAL_NET_MASK'>
		<dhcp>
			<range start='$EXTERNAL_NET.2' end='$EXTERNAL_NET.254'/>
			<host mac='$VM1_EXTERNAL_MAC' name='$VM1_NAME' ip='$VM1_EXTERNAL_IP'/>
		</dhcp>
	</ip>
</network>" > $EXTERNAL_NET_XML
#---<END: External network template>---

echo "Creating internal.xml..."
INTERNAL_NET_XML=$SCRPATH'networks/internal.xml'
#---<START: Internal network template>---
echo"<network>
	<name>${INTERNAL_NET_NAME}</name>
</network>" > $INTERNAL_NET_XML
#---<END: Internal network template>---

echo "Creating management.xml..."
MANAGEMENT_NET_XML=$SCRPATH'networks/management.xml'
#---<START: Management network template>---
echo"<network>
  <name>${MANAGEMENT_NET_NAME}</name>
  <ip address='$MANAGEMENT_HOST_IP' netmask='$MANAGEMENT_NET_MASK'/>
</network>" > $MANAGEMENT_NET_XML
#---<END: Management network template>---

echo "Defining networks..."
virsh net-define $EXTERNAL_NET_XML
virsh net-define $INTERNAL_NET_XML
virsh net-define $MANAGEMENT_NET_XML

echo "Starting networks..."
virsh net-start external
virsh net-start internal
virsh net-start management

echo "Generate instance-id for VM1:"
VM1_INSTANCE_ID=`uuidgen`
echo "VM1_INSTANCE_ID: $VM1_INSTANCE_ID"

echo "Generate instance-id for VM2:"
VM2_INSTANCE_ID=`uuidgen`
echo "VM2_INSTANCE_ID: $VM2_INSTANCE_ID"

echo "Creating VMs meta-data profiles..."
echo"instance-id: $VM1_INSTANCE_ID
hostname: ${VM1_NAME}
local-hostname: ${VM1_NAME}
network-interfaces: |
	auto ${VM1_EXTERNAL_IF}
	iface ${VM1_EXTERNAL_IF} inet dhcp

	auto ${VM1_INTERNAL_IF}
	iface ${VM1_INTERNAL_IF} inet static
	address ${VM1_INTERNAL_IP}
	network ${INTERNAL_NET_IP}
	netmask ${INTERNAL_NET_MASK}

	auto ${VM1_MANAGEMENT_IF}
	iface ${VM1_MANAGEMENT_IF} inet static
	address ${VM1_MANAGEMENT_IP}
	network ${MANAGEMENT_NET_IP}
	netmask ${MANAGEMENT_NET_MASK}"> $SCRPATH'config-drives/'$VM1_NAME'-config/meta-data'

echo"instance-id: $VM2_INSTANCE_ID
hostname: ${VM2_NAME}
local-hostname: ${VM2_NAME}
network-interfaces: |
	auto ${VM2_INTERNAL_IF}
	iface ${VM2_INTERNAL_IF} inet static
	address ${VM2_INTERNAL_IP}
	network ${INTERNAL_NET_IP}
	netmask ${INTERNAL_NET_MASK}
	gateway ${VM1_INTERNAL_IP}
	dns-nameservers ${VM_DNS}

	auto ${VM2_MANAGEMENT_IF}
	iface ${VM2_MANAGEMENT_IF} inet static
	address ${VM2_MANAGEMENT_IP}
	network ${MANAGEMENT_NET_IP}
	netmask ${MANAGEMENT_NET_MASK}"> $SCRPATH'config-drives/'$VM2_NAME'-config/meta-data'
