#!/bin/bash

set -eux

cd "$(dirname "$0")"

function ssh_to() {
    local ip="10.0.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..7}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 4 \
        --host-passthrough \
        --memory 16384 \
        --disk 100 \
        --ephemeral-disk 100 \
        --ephemeral-disk 100 \
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
    enp7s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.0.124.1${i}/24          
EOF
done


for i in {1..7}; do
    virsh detach-interface "node-${i}.localdomain" network --config

    virsh attach-interface "node-${i}.localdomain" network virbr-mgt \
        --model virtio --config
    virsh attach-interface "node-${i}.localdomain" network virbr-sto \
        --model virtio --config
    virsh attach-interface "node-${i}.localdomain" network virbr-ser \
        --model virtio --config

    virsh start "node-${i}.localdomain"
done


for i in {1..7}; do
    until ssh_to "${i}" -t -- cloud-init status --wait; do
        sleep 1
    done

    ssh_to "${i}" -t -- sudo apt update -y
    ssh_to "${i}" -t -- sudo apt upgrade -y
    ssh_to "${i}" -t -- sudo timedatectl set-timezone America/New_York
    ssh_to "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils iperf iperf3 mtr traceroute netcat sshpass socat python3 python2 python3-dev python2-dev
    ssh_to "${i}" -t -- echo "root:gprm8350" | sudo chpasswd

    # LP: #2065911
    # TODO: make it permanent across reboots
    ssh_to "${i}" -- sudo ip link set enp7s0 up
    ssh_to "${i}" -- sudo ip link set enp9s0 up
done
