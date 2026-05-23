#!/bin/bash

set -eux

cd "$(dirname "$0")"

function ssh_node() {
    local ip="10.0.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..3}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 16 \
        --host-passthrough \
        --memory 65536 \
        --disk 100 \
        --ephemeral-disk 100 \
        --ephemeral-disk 100 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --no-start \
        "node${i}.cozystack.dev" \
        release=jammy
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.0.123.1${i}/24
      routes:
        - to: default
          via: 10.0.123.1
      nameservers:
        addresses:
          - 10.0.123.1
    enp9s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.0.124.1${i}/24
EOF
done

for i in {1..3}; do
    virsh detach-interface "node${i}.cozystack.dev" network --config
    
    virsh attach-interface "node${i}.cozystack.dev" network virbr-mgt --model virtio --config
    virsh attach-interface "node${i}.cozystack.dev" network virbr-serv --model virtio --config

    virsh start "node${i}.cozystack.dev"
done

for i in {1..3}; do
    until ssh_node "${i}" -t -- cloud-init status --wait; do
        sleep 1
    done

    ssh_node "${i}" -t -- sudo apt update -y
    ssh_node "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils sshpass

    ssh_node "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_node "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_node "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_node "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_node "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_node "${i}" -t -- sudo systemctl restart sshd
    ssh_node "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

done

for i in {1..3}; do

    ssh_node "${i}" -t -- sudo reboot

done
