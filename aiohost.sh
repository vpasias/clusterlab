#!/bin/bash

set -eux

cd "$(dirname "$0")"

cat <<EOF | virsh net-define /dev/stdin
<network>
  <name>virbr-mgt</name>
  <bridge name='virbr-mgt' stp='off'/>
  <forward mode='nat'/>
  <ip address='172.16.1.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

cat <<EOF | virsh net-define /dev/stdin
<network>
  <name>virbr-ser</name>
  <bridge name='virbr-ser' stp='off'/>
  <forward mode='nat'/>
  <ip address='172.16.2.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

virsh net-autostart virbr-mgt
virsh net-start virbr-mgt

virsh net-autostart virbr-ser
virsh net-start virbr-ser

function ssh_to() {
    local ip="172.16.1.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..1}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 60 \
        --host-passthrough \
        --memory 368640 \
        --disk 200 \
        --ephemeral-disk 1000 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --no-start \
        "node-${i}.localdomain" \
        release=noble
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 172.16.1.1${i}/24
      routes:
        - to: default
          via: 172.16.1.1
      nameservers:
        addresses:
          - 8.8.8.8
    enp7s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
EOF
done

for i in {1..1}; do
    virsh detach-interface "node-${i}.localdomain" network --config

    virsh attach-interface "node-${i}.localdomain" network virbr-mgt \
        --model virtio --config
    virsh attach-interface "node-${i}.localdomain" network virbr-ser \
        --model virtio --config

    virsh start "node-${i}.localdomain"
done

sleep 60

for i in {1..1}; do

    ssh_to "${i}" -t -- sudo apt update -y
    ssh_to "${i}" -t -- sudo apt upgrade -y
    ssh_to "${i}" -t -- sudo timedatectl set-timezone America/New_York
    ssh_to "${i}" -t -- sudo apt-get install -y git vim wget curl

    ssh_to "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_to "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_to "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_to "${i}" -t -- sudo systemctl restart ssh
    ssh_to "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

done

ssh_to 1 -- 'sudo tee -a /etc/hosts <<EOF
172.16.1.11 node-1 node-1.localdomain
EOF'

for i in {1..1}; do

    ssh_to "${i}" -t -- sudo reboot

done
