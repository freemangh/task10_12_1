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
        ssh-keygen -t rsa -b 2048 -C "khvastunov@gmail.com" -f $HOME/.ssh/id_rsa -q -N ""
fi

echo "Creating external.xml..."
EXTERNAL_NET_XML=$SCRPATH'networks/external.xml'
echo "EXTERNAL_NET_XML: $EXTERNAL_NET_XML"
#---<START: External network template>---
echo "<network>
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
echo "INTERNAL_NET_XML: $INTERNAL_NET_XML"
#---<START: Internal network template>---
echo "<network>
	<name>${INTERNAL_NET_NAME}</name>
</network>" > $INTERNAL_NET_XML
#---<END: Internal network template>---

echo "Creating management.xml..."
MANAGEMENT_NET_XML=$SCRPATH'networks/management.xml'
echo "MANAGEMENT_NET_XML: $MANAGEMENT_NET_XML"
#---<START: Management network template>---
echo "<network>
  <name>${MANAGEMENT_NET_NAME}</name>
  <ip address='$MANAGEMENT_HOST_IP' netmask='$MANAGEMENT_NET_MASK'/>
</network>" > $MANAGEMENT_NET_XML
#---<END: Management network template>---

echo "Defining networks..."
virsh net-define $EXTERNAL_NET_XML
virsh net-define $INTERNAL_NET_XML
virsh net-define $MANAGEMENT_NET_XML

echo "Starting networks..."
virsh net-autostart external
virsh net-autostart internal
virsh net-autostart management
virsh net-start external
virsh net-start internal
virsh net-start management

echo "Generate instance-id for VM1:"
VM1_INSTANCE_ID=`uuidgen`
echo "VM1_INSTANCE_ID: $VM1_INSTANCE_ID"

echo "Generate instance-id for VM2:"
VM2_INSTANCE_ID=`uuidgen`
echo "VM2_INSTANCE_ID: $VM2_INSTANCE_ID"

echo "Creating VMs cloud-init meta-data profiles..."
#---<START: VM1 meta-data template>---
echo "instance-id: $VM1_INSTANCE_ID
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
#---<END: VM1 meta-data template>---
#---<START: VM2 meta-data template>---
echo "instance-id: $VM2_INSTANCE_ID
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
#---<END: VM2 meta-data template>---

echo "Creating VMs cloud-init user-data profiles..."
SSH_P_K=`cat $SSH_PUB_KEY`
#---<START: VM1 user-data template>---
echo "#cloud-config
chpasswd: { expire: False }
password: qwerty
runcmd:
 - 'hostname ${VM1_NAME}'
 - 'echo ${VM1_NAME} > /etc/hostname'
 - 'echo ${VM1_NAME} >> /etc/hosts'
 - 'echo nameserver ${VM_DNS} >> /etc/resolv.conf'
 - 'ip addr add ${VM1_INTERNAL_IP}/24 dev ${VM1_INTERNAL_IF}'
 - 'ip link set up dev ${VM1_INTERNAL_IF}'
 - 'ip addr add ${VM1_MANAGEMENT_IP}/24 dev ${VM1_MANAGEMENT_IF}'
 - 'ip link set up dev ${VM1_MANAGEMENT_IF}'
 - 'ip link add ${VXLAN_IF} type vxlan id ${VID} remote ${VM2_INTERNAL_IP} local ${VM1_INTERNAL_IP} dstport 4789'
 - 'ip addr add ${VM1_VXLAN_IP}/24 dev ${VXLAN_IF}'
 - 'ip link set up dev ${VXLAN_IF}'
 - 'sysctl net.ipv4.ip_forward=1'
 - 'iptables -t nat -A POSTROUTING -o ${VM1_EXTERNAL_IF} -j MASQUERADE'
 - 'iptables -A FORWARD -i ${VM1_INTERNAL_IF} -o ${VM1_EXTERNAL_IF} -j ACCEPT'
 - 'iptables -A FORWARD -i ${VM1_EXTERNAL_IF} -o ${VM1_INTERNAL_IF} -j ACCEPT'
 - 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -'
 - 'sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"'
 - 'sudo apt-get update'
 - 'sudo apt-get install docker-ce docker-compose -y'

package_upgrade: false

ssh_authorized_keys:
 - $SSH_P_K" > $SCRPATH'config-drives/'$VM1_NAME'-config/user-data'
#cat $SSH_PUB_KEY >> $SCRPATH'config-drives/'$VM1_NAME'-config/user-data'
#---<END: VM1 user-data template>---
#---<START: VM2 user-data template>---
echo "#cloud-config
chpasswd: { expire: False }
password: qwerty
runcmd:
 - 'hostname ${VM2_NAME}'
 - 'echo ${VM2_NAME} > /etc/hostname'
 - 'echo ${VM2_NAME} >> /etc/hosts'
 - 'echo nameserver ${VM_DNS} >> /etc/resolv.conf'
 - 'ip addr add ${VM2_INTERNAL_IP}/24 dev ${VM2_INTERNAL_IF}'
 - 'ip link set up dev ${VM2_INTERNAL_IF}'
 - 'ip route add default via ${VM1_INTERNAL_IP}'
 - 'ip addr add ${VM2_MANAGEMENT_IP}/24 dev ${VM2_MANAGEMENT_IF}'
 - 'ip link set up dev ${VM2_MANAGEMENT_IF}'
 - 'ip link add ${VXLAN_IF} type vxlan id ${VID} remote ${VM1_INTERNAL_IP} local ${VM2_INTERNAL_IP} dstport 4789'
 - 'ip addr add ${VM2_VXLAN_IP}/24 dev ${VXLAN_IF}'
 - 'ip link set up dev ${VXLAN_IF}'
 - 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -'
 - 'sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"'
 - 'sudo apt-get update'
 - 'sudo apt-get install docker-ce docker-compose -y'

package_upgrade: false

ssh_authorized_keys:
 - $SSH_P_K" > $SCRPATH'config-drives/'$VM2_NAME'-config/user-data'
#cat $SSH_PUB_KEY >> $SCRPATH'config-drives/'$VM2_NAME'-config/user-data'
#---<END: VM2 user-data template>---

echo "Creating VMs XML profiles from temlpates..."
#---<START: VM1 config template>---
echo "<domain type='${VM_VIRT_TYPE}'>
	<name>vm1</name>
	<memory unit='MiB'>${VM1_MB_RAM}</memory>
	<vcpu placement='static'>${VM1_NUM_CPU}</vcpu>
	<os>
		<type>${VM_TYPE}</type>
		<boot dev='hd'/>
	</os>
	<devices>
		<disk type='file' device='disk'>
			<driver name='qemu' type='qcow2'/>
			<source file='${VM1_HDD}'/>
			<target dev='vda' bus='virtio'/>
		</disk>
		<disk type='file' device='cdrom'>
			<driver name='qemu' type='raw'/>
			<source file='${VM1_CONFIG_ISO}'/>
			<target dev='hdc' bus='ide'/>
			<readonly/>
		</disk>
		<interface type='network'>
			<mac address='${VM1_EXTERNAL_MAC}'/>
			<source network='${EXTERNAL_NET_NAME}'/>
			<model type='virtio'/>
		</interface>
		<interface type='network'>
			<source network='${INTERNAL_NET_NAME}'/>
			<model type='virtio'/>
			<protocol family='ipv4'>
				<ip address='${VM1_INTERNAL_IP}' prefix='24'/>
				<route gateway='${INTERNAL_NET}.1'/>
			</protocol>
		</interface>
		<interface type='network'>
			<source network='${MANAGEMENT_NET_NAME}'/>
			<model type='virtio'/>
		</interface>
		<serial type='pty'>
			<source path='/dev/pts/0'/>
			<target port='0'/>
		</serial>
		<console type='pty' tty='/dev/pts/0'>
			<source path='/dev/pts/0'/>
			<target type='serial' port='0'/>
		</console>
		<graphics type='vnc' port='-1' autoport='yes'/>
	</devices>
</domain>" > $SCRPATH'vm1.xml'
#---<END: VM1 config template>---
#---<START: VM2 config template>---
echo "<domain type='${VM_VIRT_TYPE}'>
	<name>${VM2_NAME}</name>
	<memory unit='MiB'>${VM2_MB_RAM}</memory>
	<vcpu placement='static'>${VM2_NUM_CPU}</vcpu>
	<os>
		<type>${VM_TYPE}</type>
		<boot dev='hd'/>
	</os>
	<devices>
		<disk type='file' device='disk'>
			<driver name='qemu' type='qcow2'/>
			<source file='${VM2_HDD}'/>
			<target dev='vda' bus='virtio'/>
		</disk>
		<disk type='file' device='cdrom'>
			<driver name='qemu' type='raw'/>
			<source file='${VM2_CONFIG_ISO}'/>
			<target dev='hdc' bus='ide'/>
			<readonly/>
		</disk>
		<interface type='network'>
			<source network='${INTERNAL_NET_NAME}'/>
			<model type='virtio'/>
				<protocol family='ipv4'>
					<ip address='${VM2_INTERNAL_IP}' prefix='24'/>
					<route gateway='{INTERNAL_NET}.1'/>
				</protocol>
		</interface>
		<interface type='network'>
			<source network='${MANAGEMENT_NET_NAME}'/>
			<model type='virtio'/>
		</interface>
		<serial type='pty'>
			<source path='/dev/pts/0'/>
			<target port='0'/>
		</serial>
		<console type='pty' tty='/dev/pts/0'>
			<source path='/dev/pts/0'/>
			<target type='serial' port='0'/>
		</console>
		<graphics type='vnc' port='-1' autoport='yes'/>
	</devices>
</domain>" > $SCRPATH'vm2.xml'
#---<END: VM2 config template>---

echo "Creating config-drives..."
mkisofs -o "$VM1_CONFIG_ISO" -V cidata -r -J $SCRPATH'config-drives/vm1-config'
genisoimage -output "$VM2_CONFIG_ISO" -volid cidata -joliet -rock $SCRPATH'config-drives/vm2-config'

echo "Defining VMs from XMLs..."
virsh define $SCRPATH'vm1.xml'
virsh define $SCRPATH'vm2.xml'
#
echo "Starting VMs..."
virsh start vm1
virsh start vm2
