#!/bin/bash

usage="usage: $0 bridge|ovs <base_image> <guest_name> [virt_system (default KVM - only virt system supported so far)]"

if [ -z $3 ]; then
  echo $usage
  exit 1
fi
network_type=$1
base_image=$2
guest_name=$3

GUEST_DIR=/usr/local/etc/ovs-testing/guests

if [ ${network_type} == "bridge" ]; then
  UP_SCRIPT='/usr/local/etc/bridge-ifup'
  DOWN_SCRIPT='/usr/local/etc/bridge-ifdown'

elif [ ${network_type} == "ovs" ]; then
  UP_SCRIPT='/usr/local/etc/ovs-ifup'
  DOWN_SCRIPT='/usr/local/etc/ovs-ifdown'

else
  echo 'error: ${network_type} unknown network type'
  echo $usage
  exit 1
fi

if [ ! -e ${GUEST_DIR}/${guest_name}/mac_addr ]; then
  MAC_ADDR=`head -n ${GUEST_DIR}/${guest_name}/mac_addr` 
else
  echo 'error: missing required configuration at $GUEST_DIR/${guest_name}/mac_addr'
  echo $usage
  exit 1
fi


modprobe kvm

#create temporary cow file to use as root filesystem
guest_disk="${base_image}-${guest_name}.qcow2"

qemu-img create -f qcow2 -o backing_fmt=qcow2,backing_file=${base_image} ${guest_disk}

qemu-nbd ${guest_disk} &
sleep 2
qemu_nbd_pid=`echo $!`
nbd-client localhost 1024 /dev/nbd0
mkdir -p /mnt/${guest_name}
sleep 2
mount /dev/nbd0p1 /mnt/${guest_name}
cp -a ${GUEST_DIR}/copy_into_filesystem /mnt/$GUEST/
umount /mnt/${guest_name} kill ${qemu_nbd_pid} 

#TODO add virt_system cases here
#TODO add options to modify this command (memory, drivers, etc.)

kvm_command="kvm -m 1024 -net nic,macaddr=${MAC_ADDR},model=virtio -net tap,script=${UP_SCRIPT},downscript=${DOWN_SCRIPT} -drive file=${guest_disk},if=virtio,boot=on"

#TODO add option to suppress with quiet option
echo "running: ${kvm_command}"
`${kvm_command}`

#TODO have option to not delete guest disk...for forensics?
rm $guest_disk
