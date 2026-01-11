#!/bin/bash
#
# https://docs.siderolabs.com/talos/v1.12/platform-specific-installations/virtualized-platforms/kvm
# https://gist.github.com/cyrenity/67469dce33cf4eb4483486637c06d7be
HOME=/mnt/extra/

cat > /mnt/extra/management.xml <<EOF
<network>
  <name>management</name>
  <bridge name="management" stp="on" delay="0"/>
  <forward mode='nat'>
    <nat/>
  </forward>
  <ip address="192.168.254.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.254.2" end="192.168.254.254"/>
    </dhcp>
  </ip>
</network>
EOF

cat > /mnt/extra/service.xml <<EOF
<network>
  <name>service</name>
  <bridge name="virbr101" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:9a:9a:9a'/>
  <ip address='172.16.2.1' netmask='255.255.255.0'/>
</network>
EOF

virsh net-define /mnt/extra/management.xml && virsh net-autostart management && virsh net-start management
virsh net-define /mnt/extra/service.xml && virsh net-autostart service && virsh net-start service

VM1="node1"
VM2="node2"
VM3="node3"
VM4="node4"
VM5="node5"
VM6="node6"
IP_ADDRESS1="192.168.254.21"
MAC_ADDRESS1="52:54:00:f2:d3:21"
IP_ADDRESS2="192.168.254.22"
MAC_ADDRESS2="52:54:00:f2:d3:22"
IP_ADDRESS3="192.168.254.23"
MAC_ADDRESS3="52:54:00:f2:d3:23"
IP_ADDRESS4="192.168.254.24"
MAC_ADDRESS4="52:54:00:f2:d3:24"
IP_ADDRESS5="192.168.254.25"
MAC_ADDRESS5="52:54:00:f2:d3:25"
IP_ADDRESS6="192.168.254.26"
MAC_ADDRESS6="52:54:00:f2:d3:26" 

virsh net-update --network management --command add-last --section ip-dhcp-host --xml "<host mac='${MAC_ADDRESS1}' name='${VM}' ip='${IP_ADDRESS1}'/>" --live --config
virsh net-update --network management --command add-last --section ip-dhcp-host --xml "<host mac='${MAC_ADDRESS2}' name='${VM}' ip='${IP_ADDRESS2}'/>" --live --config
virsh net-update --network management --command add-last --section ip-dhcp-host --xml "<host mac='${MAC_ADDRESS3}' name='${VM}' ip='${IP_ADDRESS3}'/>" --live --config
virsh net-update --network management --command add-last --section ip-dhcp-host --xml "<host mac='${MAC_ADDRESS4}' name='${VM}' ip='${IP_ADDRESS4}'/>" --live --config
virsh net-update --network management --command add-last --section ip-dhcp-host --xml "<host mac='${MAC_ADDRESS5}' name='${VM}' ip='${IP_ADDRESS5}'/>" --live --config
virsh net-update --network management --command add-last --section ip-dhcp-host --xml "<host mac='${MAC_ADDRESS6}' name='${VM}' ip='${IP_ADDRESS6}'/>" --live --config

ip a && sudo virsh net-list --all

sleep 20

virt-install --virt-type kvm --name ${VM1} --ram 32768 --vcpus 8 --disk path=/mnt/extra/${VM1}.qcow2,bus=virtio,size=40,format=qcow2 --cdrom metal-amd64.iso --os-variant=linux2022 \
  --network network=management,mac=${MAC_ADDRESS1} --boot hd,cdrom --noautoconsole

