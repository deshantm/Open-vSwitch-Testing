#!/bin/bash

usage="usage: $0 <bridge|ovs> <net_dev (e.g eth0)> <bridge_name> <IP_address> [no_network_teardown]"

user=`whoami`
if [ $user != "root" ]; then
  echo 'must be root'
  exit 1
fi

if [ -z $4 ]; then
  echo $usage
  exit 1
fi 

if [ ! -z $5 ]; then
  #bring down network
  killall -9 dhclient
  for ethN in `ifconfig -a | grep eth | awk '{print $1}'`; do
    ifconfig ${ethN} 0.0.0.0 down
  done
fi

network_type=$1
network_device=$2
bridge_name=$3
IP_address=$4

#TODO detect (automatically or in data file) or allow ovs_bridge on command line
ovs_bridge=${bridge_name}
#TODO same with name of bridged-network bridge name

if [ "x" == "${OVS_ROOT}x" ]; then
  OVS_ROOT='/usr/local/src/ovs-src/'
fi

if [ $1 == "bridge" ]; then
  ovs-vsctl del-port ${network_device}
  ifconfig ${ovs_bridge} down
  ovs-vsctl -- --if-exists del-br ${ovs_bridge}
  ovs-appctl -t ovsdb-server exit
  ovs-appctl -t ovs-vswitchd exit
  rmmod openvswitch_mod
  modprobe bridge
  brctl addbr ${bridge_name}
  ifconfig ${bridge_name} $IP_address
  brctl addif ${bridge_name} ${network_device}
  ifconfig ${network_device} 0.0.0.0 up
elif [ $1 == "ovs" ]; then
  brctl delif ${bridge_name} ${network_device}
  ifconfig ${bridge_name} down
  brctl delbr ${bridge_name}
  rmmod bridge
  insmod ${OVS_ROOT}/datapath/linux-2.6/openvswitch_mod.ko
  ovsdb-tool create /usr/local/etc/ovs-vswitchd.conf.db ${OVS_ROOT}/vswitchd/vswitch.ovsschema
  ovs-appctl -t ovsdb-server
  ovs-appctl -t ovs-vswitchd
  gnome-terminal --command='ovsdb-server /usr/local/etc/ovs-vswitchd.conf.db --remote=punix:/usr/local/var/run/openvswitch/db.sock --pidfile' &
  ovs-vsctl init
  gnome-terminal --command='ovs-vswitchd unix:/usr/local/var/run/openvswitch/db.sock --pidfile' &
  sleep 1
  ovs-vsctl -- --if-exists del-br ${ovs_bridge}
  ovs-vsctl add-br ${ovs_bridge}
  sleep 1
  ifconfig $ovs_bridge $2
  ovs-vsctl add-port ${ovs_bridge} ${network_device}
  ifconfig ${network_device} 0.0.0.0 up
fi
