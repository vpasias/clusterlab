#!/bin/bash

set -eux

cd "$(dirname "$0")"

cat <<EOF | virsh net-define /dev/stdin
<network>
  <name>virbr-mgt</name>
  <bridge name='virbr-mgt' stp='off'/>
  <forward mode='nat'/>
  <dns>
    <host ip='192.168.254.101'>
      <hostname>esxi1.cloud.ds.dev</hostname>
    </host>
    <host ip='192.168.254.102'>
      <hostname>esxi2.cloud.ds.dev</hostname>
    </host>
    <host ip='192.168.254.103'>
      <hostname>esxi3.cloud.ds.dev</hostname>
    </host>
    <host ip='192.168.254.200'>
      <hostname>vcenter.cloud.ds.dev</hostname>
    </host>
  </dns>
  <ip address='192.168.254.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

virsh net-autostart virbr-mgt
virsh net-start virbr-mgt

function ssh_to() {
    local ip="192.168.254.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..1}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 60 \
        --host-passthrough \
        --memory 376832 \
        --disk 1400 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --no-start \
        "node-${i}.cloud.ds.dev" \
        release=resolute
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 192.168.254.1${i}/24
      routes:
        - to: default
          via: 192.168.254.1
      nameservers:
        addresses:
          - 8.8.8.8
EOF
done

for i in {1..1}; do
    virsh detach-interface "node-${i}.cloud.ds.dev" network --config

    virsh attach-interface "node-${i}.cloud.ds.dev" network virbr-mgt --model virtio --config

    virsh start "node-${i}.cloud.ds.dev"
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
    ssh_to "${i}" -t -- 'echo "options kvm ignore_msrs=1 report_ignored_msrs=0" | sudo tee -a /etc/modprobe.d/qemu-system-x86.conf >/dev/null'
    ssh_to "${i}" -t -- 'echo "options kvm_intel nested=1 enable_apicv=0 ept=1" | sudo tee -a /etc/modprobe.d/qemu-system-x86.conf >/dev/null'

    ssh_to "${i}" -t -- "sudo DEBIAN_FRONTEND=noninteractive sudo apt-get install task-cinnamon-desktop --install-recommends -y"
    ssh_to "${i}" -t -- "sudo DEBIAN_FRONTEND=noninteractive sudo apt-get install xrdp --install-recommends -y"
    ssh_to "${i}" -t -- "sudo ufw allow from any to any port 3389 proto tcp"
    ssh_to "${i}" -t -- "sudo systemctl enable --now xrdp"
    ssh_to "${i}" -t -- "sudo systemctl set-default graphical.target"

done

ssh_to 1 -- 'sudo tee -a /etc/hosts <<EOF
192.168.254.11 node-1 node-1.cloud.ds.dev
192.168.254.101 esxi1.cloud.ds.dev
192.168.254.102 esxi2.cloud.ds.dev
192.168.254.103 esxi3.cloud.ds.dev
192.168.254.200 vcenter.cloud.ds.dev
EOF'

for i in {1..1}; do

    ssh_to "${i}" -t -- sudo reboot

done
