#!/bin/bash
#
HOME=/home/iason/

cat > /home/iason/cluster.xml <<EOF
<network>
  <name>cluster</name>
  <bridge name="br1" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:97:98:99'/>
  <ip address='172.16.1.1' netmask='255.255.255.0'/>
</network>
EOF

cat > /home/iason/service.xml <<EOF
<network>
  <name>service</name>
  <bridge name="br2" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:9a:9b:9c'/>
  <ip address='172.16.2.1' netmask='255.255.255.0'/>
</network>
EOF

sudo virsh net-define /home/iason/cluster.xml && sudo virsh net-autostart cluster && sudo virsh net-start cluster
sudo virsh net-define /home/iason/service.xml && sudo virsh net-autostart service && sudo virsh net-start service

ip a && sudo virsh net-list --all

#ip link add name br1 type bridge
#ip link set dev br1 up
#ip link add name br2 type bridge
#ip link set dev br2 up
#ip a 
