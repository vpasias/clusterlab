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
    enp9s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.0.124.1${i}/24
    enp10s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
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

    ssh_to "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_to "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_to "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- sudo systemctl restart sshd
    ssh_to "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

    # LP: #2065911
    # TODO: make it permanent across reboots
    ssh_to "${i}" -- sudo ip link set enp9s0 up
    ssh_to "${i}" -- sudo ip link set enp10s0 up
done

ssh_to 1 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 node-1 node-1.localdomain
10.0.123.12 node-2 node-2.localdomain
10.0.123.13 node-3 node-3.localdomain
10.0.123.14 node-4 node-4.localdomain
10.0.123.15 node-5 node-5.localdomain
10.0.123.16 node-6 node-6.localdomain
10.0.123.17 node-7 node-7.localdomain
10.0.123.5 internal.localdomain
10.0.123.10 public.localdomain

10.0.124.11 node-1
10.0.124.12 node-2
10.0.124.13 node-3
10.0.124.14 node-4
10.0.124.15 node-5
10.0.124.16 node-6
10.0.124.17 node-7
EOF'

for i in {1..7}; do

    ssh_to "${i}" -t -- sudo apt-get update -y
    ssh_to "${i}" -t -- sudo apt-get install ca-certificates curl -y
    ssh_to "${i}" -t -- sudo install -m 0755 -d /etc/apt/keyrings
    ssh_to "${i}" -t -- sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    ssh_to "${i}" -t -- sudo chmod a+r /etc/apt/keyrings/docker.asc
    ssh_to "${i}" -t -- 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
    ssh_to "${i}" -t -- sudo apt-get update -y
    ssh_to "${i}" -t -- sudo apt-get install docker-ce docker-ce-cli containerd.io -y
    ssh_to "${i}" -t -- sudo systemctl enable --now docker

done

for i in {1..7}; do

    ssh_to "${i}" -t -- 'sudo chmod -x /etc/update-motd.d/*'
    ssh_to "${i}" -t -- 'cat << EOF | sudo tee /etc/update-motd.d/01-custom
    #!/bin/sh
    echo "****************************WARNING****************************************
    UNAUTHORISED ACCESS IS PROHIBITED. VIOLATORS WILL BE PROSECUTED.
    *********************************************************************************"
    EOF'
    ssh_to "${i}" -t -- sudo chmod +x /etc/update-motd.d/01-custom

done

for i in {1..7}; do

    ssh_to "${i}" -t -- sudo reboot

done
