#!/bin/bash

set -eux

cd "$(dirname "$0")"

function ssh_to() {
    local ip="10.0.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..1}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 60 \
        --host-passthrough \
        --memory 327680 \
        --disk 1400 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --no-start \
        "node-${i}.localdomain" \
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
EOF
done

for i in {1..1}; do
    virsh detach-interface "node-${i}.localdomain" network --config

    virsh attach-interface "node-${i}.localdomain" network virbr-mgt \
        --model virtio --config

    virsh start "node-${i}.localdomain"
done


for i in {1..1}; do
    until ssh_to "${i}" -t -- cloud-init status --wait; do
        sleep 1
    done

    ssh_to "${i}" -t -- sudo apt update -y
    ssh_to "${i}" -t -- sudo apt upgrade -y
    ssh_to "${i}" -t -- sudo timedatectl set-timezone America/New_York
    ssh_to "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils iperf iperf3 mtr traceroute netcat sshpass socat python3-pip python3 python2 python3-dev python2-dev

    ssh_to "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_to "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_to "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_to "${i}" -t -- sudo systemctl restart sshd
    ssh_to "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

done

ssh_to 1 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 node-1 node-1.localdomain
EOF'

for i in {1..1}; do

    ssh_to "${i}" -t -- sudo reboot

done
