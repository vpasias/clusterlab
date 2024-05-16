#!/bin/bash
#
HOME=/mnt/extra/

cat > /mnt/extra/internal.xml <<EOF
<network>
  <name>internal</name>
  <forward mode='nat'/>
  <bridge name='virbr100' stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:8a:8b:8c'/>
  <ip address='172.16.1.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='172.16.1.199' end='172.16.1.254'/>
      <host mac='52:54:00:8a:8b:c0' name='n0' ip='172.16.1.20'/>
      <host mac='52:54:00:8a:8b:c1' name='n1' ip='172.16.1.21'/>
      <host mac='52:54:00:8a:8b:c2' name='n2' ip='172.16.1.22'/>
      <host mac='52:54:00:8a:8b:c3' name='n3' ip='172.16.1.23'/>
      <host mac='52:54:00:8a:8b:c4' name='n4' ip='172.16.1.24'/>
      <host mac='52:54:00:8a:8b:c5' name='n5' ip='172.16.1.25'/>
      <host mac='52:54:00:8a:8b:c6' name='n6' ip='172.16.1.26'/>
      <host mac='52:54:00:8a:8b:c7' name='n7' ip='172.16.1.27'/>
      <host mac='52:54:00:8a:8b:c8' name='n8' ip='172.16.1.28'/>
      <host mac='52:54:00:8a:8b:c9' name='n9' ip='172.16.1.29'/>
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

cat > /mnt/extra/cephpublic.xml <<EOF
<network>
  <name>cephpublic</name>
  <bridge name="virbr102" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:9b:9b:9b'/>
  <ip address='172.16.3.1' netmask='255.255.255.0'/>
</network>
EOF

cat > /mnt/extra/cephcluster.xml <<EOF
<network>
  <name>cephcluster</name>
  <bridge name="virbr103" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:9c:9c:9c'/>
  <ip address='172.16.4.1' netmask='255.255.255.0'/>
</network>
EOF

cat > /mnt/extra/public.xml <<EOF
<network>
  <name>public</name>
  <bridge name="virbr104" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:9e:9e:9e'/>
  <ip address='10.8.60.0' netmask='255.255.255.0'/>
</network>
EOF

cat > /mnt/extra/provider.xml <<EOF
<network>
  <name>provider</name>
  <bridge name="virbr105" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:9d:9d:9d'/>
  <ip address='172.16.5.1' netmask='255.255.255.0'/>
</network>
EOF

virsh net-define /mnt/extra/internal.xml && virsh net-autostart internal && virsh net-start internal
virsh net-define /mnt/extra/service.xml && virsh net-autostart service && virsh net-start service
virsh net-define /mnt/extra/cephpublic.xml && virsh net-autostart cephpublic && virsh net-start cephpublic
virsh net-define /mnt/extra/cephcluster.xml && virsh net-autostart cephcluster && virsh net-start cephcluster
virsh net-define /mnt/extra/public.xml && virsh net-autostart public && virsh net-start public
virsh net-define /mnt/extra/provider.xml && virsh net-autostart provider && virsh net-start provider

ip a && sudo virsh net-list --all

sleep 20

# Node 1
./kvm-install-vm create -c 4 -m 16384 -d 100 -t ubuntu2204 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c1 n1

# Node 2
./kvm-install-vm create -c 4 -m 16384 -d 100 -t ubuntu2204 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c2 n2

# Node 3
./kvm-install-vm create -c 4 -m 16384 -d 100 -t ubuntu2204 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c3 n3

# Node 4
./kvm-install-vm create -c 4 -m 16384 -d 100 -t ubuntu2204 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c4 n4

# Node 5
./kvm-install-vm create -c 4 -m 16384 -d 100 -t ubuntu2204 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c5 n5

sleep 60

virsh list --all && brctl show && virsh net-list --all

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i 'echo "root:gprm8350" | sudo chpasswd'; done
for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i 'echo "ubuntu:kyax7344" | sudo chpasswd'; done
for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"; done
for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"; done
for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo systemctl restart sshd"; done
for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo rm -rf /root/.ssh/authorized_keys"; done

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo hostnamectl set-hostname n$i.example.com --static"; done

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo apt update -y && sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils iperf iperf3 mtr traceroute netcat sshpass socat python3 python2 python3-dev python2-dev"; done

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo chmod -x /etc/update-motd.d/*"; done

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i 'cat << EOF | sudo tee /etc/update-motd.d/01-custom
#!/bin/sh
echo "****************************WARNING****************************************
UNAUTHORISED ACCESS IS PROHIBITED. VIOLATORS WILL BE PROSECUTED.
*********************************************************************************"
EOF'; done

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo chmod +x /etc/update-motd.d/01-custom"; done

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "cat << EOF | sudo tee /etc/modprobe.d/qemu-system-x86.conf
options kvm_intel nested=1
EOF"; done

for i in {1..5}; do virsh shutdown n$i; done && sleep 10 && virsh list --all && for i in {1..5}; do virsh start n$i; done && sleep 10 && virsh list --all

sleep 30

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo apt update -y"; done

for i in {1..5}; do qemu-img create -f qcow2 vbdnode1$i 200G; done
#for i in {1..5}; do qemu-img create -f qcow2 vbdnode2$i 200G; done
#for i in {1..5}; do qemu-img create -f qcow2 vbdnode3$i 200G; done

for i in {1..5}; do ./kvm-install-vm attach-disk -d 200 -s /mnt/extra/kvm-install-vm/vbdnode1$i.qcow2 -t vdb n$i; done
#for i in {1..3}; do ./kvm-install-vm attach-disk -d 200 -s /mnt/extra/kvm-install-vm/vbdnode2$i.qcow2 -t vdc n$i; done
#for i in {1..3}; do ./kvm-install-vm attach-disk -d 200 -s /mnt/extra/kvm-install-vm/vbdnode3$i.qcow2 -t vdd n$i; done

for i in {1..5}; do virsh attach-interface --domain n$i --type network --source service --model virtio --mac 02:00:aa:0a:01:1$i --config --live; done
for i in {1..5}; do virsh attach-interface --domain n$i --type network --source cephpublic --model virtio --mac 02:00:aa:0a:02:1$i --config --live; done
for i in {1..5}; do virsh attach-interface --domain n$i --type network --source cephcluster --model virtio --mac 02:00:aa:0a:03:1$i --config --live; done
for i in {1..5}; do virsh attach-interface --domain n$i --type network --source public --model virtio --mac 02:00:aa:0a:04:1$i --config --live; done
for i in {1..5}; do virsh attach-interface --domain n$i --type network --source provider --model virtio --mac 02:00:aa:0a:05:1$i --config --live; done

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "cat << EOF | sudo tee /etc/sysctl.d/60-lxd-production.conf
fs.inotify.max_queued_events=1048576
fs.inotify.max_user_instances=1048576
fs.inotify.max_user_watches=1048576
vm.max_map_count=262144
kernel.dmesg_restrict=1
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv6.neigh.default.gc_thresh3=8192
net.core.bpf_jit_limit=3000000000
kernel.keys.maxkeys=2000
kernel.keys.maxbytes=2000000
net.ipv4.ip_forward=1
EOF"; done

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo sysctl --system"; done

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "#echo vm.swappiness=1 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p"; done

ssh -o "StrictHostKeyChecking=no" ubuntu@n1 "cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.1.21/24
      routes:
        - to: default
          via: 172.16.1.1
          metric: 100
          on-link: true
    enp7s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.2.21/24
    enp8s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.3.21/24
EOF"

ssh -o "StrictHostKeyChecking=no" ubuntu@n2 "cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.1.22/24
      routes:
        - to: default
          via: 172.16.1.1
          metric: 100
          on-link: true
    enp7s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.2.22/24
    enp8s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.3.22/24
EOF"

ssh -o "StrictHostKeyChecking=no" ubuntu@n3 "cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.1.23/24
      routes:
        - to: default
          via: 172.16.1.1
          metric: 100
          on-link: true
    enp7s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.2.23/24
    enp8s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.3.23/24
EOF"

ssh -o "StrictHostKeyChecking=no" ubuntu@n4 "cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.1.24/24
      routes:
        - to: default
          via: 172.16.1.1
          metric: 100
          on-link: true
    enp7s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.2.24/24
    enp8s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.3.24/24
EOF"

ssh -o "StrictHostKeyChecking=no" ubuntu@n5 "cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.1.25/24
      routes:
        - to: default
          via: 172.16.1.1
          metric: 100
          on-link: true
    enp7s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.2.25/24
    enp8s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.3.25/24
EOF"

for i in {1..5}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo netplan apply"; done
sleep 40

for i in {1..5}; do virsh shutdown n$i; done && sleep 10 && virsh list --all && for i in {1..5}; do virsh start n$i; done && sleep 10 && virsh list --all
