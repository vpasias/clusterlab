#!/bin/bash
#
HOME=/mnt/extra/

cat > /mnt/extra/cluster.xml <<EOF
<network>
  <name>cluster</name>
  <bridge name="br1" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:97:98:99'/>
  <ip address='172.16.1.1' netmask='255.255.255.0'/>
</network>
EOF

cat > /mnt/extra/service.xml <<EOF
<network>
  <name>service</name>
  <bridge name="br2" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:9a:9b:9c'/>
  <ip address='172.16.2.1' netmask='255.255.255.0'/>
</network>
EOF

virsh net-define /mnt/extra/cluster.xml && virsh net-autostart cluster && virsh net-start cluster
virsh net-define /mnt/extra/service.xml && virsh net-autostart service && virsh net-start service

ip a && sudo virsh net-list --all

#ip link add name br1 type bridge
#ip link set dev br1 up
#ip link add name br2 type bridge
#ip link set dev br2 up
#ip a 
