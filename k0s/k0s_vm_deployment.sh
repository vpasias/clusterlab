#!/bin/bash

set -eux

cd "$(dirname "$0")"

cat <<EOF | virsh net-define /dev/stdin
<network>
  <name>virbr-mgt</name>
  <bridge name='virbr-mgt' stp='off'/>
  <forward mode='nat'/>
  <ip address='172.19.123.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

virsh net-autostart virbr-mgt

virsh net-start virbr-mgt

cat <<EOF | virsh net-define /dev/stdin
<network>
  <name>virbr-serv</name>
  <bridge name='virbr-serv' stp='off'/>
  <forward mode='nat'/>
  <ip address='172.19.124.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

virsh net-autostart virbr-serv

virsh net-start virbr-serv

function ssh_in() {
    local ip="172.19.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

function ssh_sn() {
    local ip="172.19.123.2${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..1}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 8 \
        --host-passthrough \
        --memory 32768 \
        --disk 100 \
        --ephemeral-disk 100 \
        --ephemeral-disk 100 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --no-start \
        "inode-0${i}" \
        release=noble
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 172.19.123.1${i}/24
      routes:
        - to: default
          via: 172.19.123.1
      nameservers:
        addresses:
          - 172.19.123.1
    enp9s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 172.19.124.1${i}/24
EOF
done

for i in {1..6}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 6 \
        --host-passthrough \
        --memory 32768 \
        --disk 100 \
        --ephemeral-disk 100 \
        --ephemeral-disk 100 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --no-start \
        "snode-0${i}" \
        release=noble
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 172.19.123.2${i}/24
      routes:
        - to: default
          via: 172.19.123.1
      nameservers:
        addresses:
          - 172.19.123.1
    enp9s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 172.19.124.2${i}/24
EOF
done

for i in {1..1}; do
    virsh detach-interface "inode-0${i}" network --config    
    virsh attach-interface "inode-0${i}" network virbr-mgt --model virtio --config
    virsh attach-interface "inode-0${i}" network virbr-serv --model virtio --config
    virsh start "inode-0${i}"
done

for i in {1..6}; do
    virsh detach-interface "snode-0${i}" network --config    
    virsh attach-interface "snode-0${i}" network virbr-mgt --model virtio --config    
    virsh attach-interface "snode-0${i}" network virbr-serv --model virtio --config    
    virsh start "snode-0${i}"
done

sleep 30

for i in {1..1}; do

    ssh_in "${i}" -t -- sudo apt update -y
    ssh_in "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils sshpass python3-pip

    ssh_in "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_in "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_in "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_in "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_in "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_in "${i}" -t -- sudo systemctl restart ssh
    ssh_in "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys
    ssh_in "${i}" -t -- 'echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu'

ssh_in "${i}" -t -- 'sudo tee -a /etc/hosts <<EOF
172.19.123.11 inode1 inode1.cloud.dev
172.19.123.21 snode1 snode1.cloud.dev
172.19.123.22 snode2 snode2.cloud.dev
172.19.123.23 snode3 snode3.cloud.dev
172.19.123.24 snode4 snode4.cloud.dev
172.19.123.25 snode5 snode5.cloud.dev
172.19.123.26 snode6 snode6.cloud.dev
EOF'

done

for i in {1..6}; do

    ssh_sn "${i}" -t -- sudo apt update -y
    ssh_sn "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils sshpass python3-pip

    ssh_sn "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_sn "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_sn "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_sn "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_sn "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_sn "${i}" -t -- sudo systemctl restart ssh
    ssh_sn "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys
    ssh_sn "${i}" -t -- 'echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu'

ssh_sn "${i}" -t -- 'sudo tee -a /etc/hosts <<EOF
172.19.123.11 inode1 inode1.cloud.dev
172.19.123.21 snode1 snode1.cloud.dev
172.19.123.22 snode2 snode2.cloud.dev
172.19.123.23 snode3 snode3.cloud.dev
172.19.123.24 snode4 snode4.cloud.dev
172.19.123.25 snode5 snode5.cloud.dev
172.19.123.26 snode6 snode6.cloud.dev
EOF'

done

for i in {1..1}; do

    ssh_in "${i}" -t -- sudo reboot

done

for i in {1..6}; do

    ssh_sn "${i}" -t -- sudo reboot

done
