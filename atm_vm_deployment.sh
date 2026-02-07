#!/bin/bash

set -eux

cd "$(dirname "$0")"

function ssh_ctl() {
    local ip="10.0.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

function ssh_ceph() {
    local ip="10.0.123.2${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

function ssh_kvm() {
    local ip="10.0.123.3${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..3}; do
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
        "ctl${i}" \
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

for i in {1..3}; do
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
        "ceph${i}" \
        release=jammy
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.0.123.2${i}/24
      routes:
        - to: default
          via: 10.0.123.1
      nameservers:
        addresses:
          - 10.0.123.1
EOF
done

for i in {1..3}; do
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
        "kvm${i}" \
        release=jammy
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.0.123.3${i}/24
      routes:
        - to: default
          via: 10.0.123.1
      nameservers:
        addresses:
          - 10.0.123.1
EOF
done

for i in {1..3}; do
    virsh detach-interface "ctl${i}" network --config
    
    virsh attach-interface "ctl${i}" network virbr-mgt --model virtio --config

    virsh start "ctl${i}"
done

for i in {1..3}; do
    virsh detach-interface "ceph${i}" network --config
    
    virsh attach-interface "ceph${i}" network virbr-mgt --model virtio --config   
    
    virsh start "ceph${i}"
done

for i in {1..3}; do
    virsh detach-interface "kvm${i}" network --config
    
    virsh attach-interface "kvm${i}" network virbr-mgt --model virtio --config    

    virsh start "kvm${i}"
done


for i in {1..3}; do
    until ssh_ctl "${i}" -t -- cloud-init status --wait; do
        sleep 1
    done

    ssh_ctl "${i}" -t -- sudo apt update -y
    ssh_ctl "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils sshpass

    ssh_ctl "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_ctl "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_ctl "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_ctl "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_ctl "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_ctl "${i}" -t -- sudo systemctl restart sshd
    ssh_ctl "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

ssh_ctl "${i}" -t -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 ctl1 ctl1.cloud.atmosphere.dev
10.0.123.12 ctl2 ctl2.cloud.atmosphere.dev
10.0.123.13 ctl3 ctl3.cloud.atmosphere.dev
10.0.123.21 ceph1 ceph1.cloud.atmosphere.dev
10.0.123.22 ceph2 ceph2.cloud.atmosphere.dev
10.0.123.23 ceph3 ceph3.cloud.atmosphere.dev
10.0.123.31 kvm1 kvm1.cloud.atmosphere.dev
10.0.123.32 kvm2 kvm2.cloud.atmosphere.dev
10.0.123.33 kvm3 kvm3.cloud.atmosphere.dev
EOF'

done

for i in {1..3}; do
    until ssh_ceph "${i}" -t -- cloud-init status --wait; do
        sleep 1
    done

    ssh_ceph "${i}" -t -- sudo apt update -y
    ssh_ceph "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils sshpass

    ssh_ceph "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_ceph "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_ceph "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_ceph "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_ceph "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_ceph "${i}" -t -- sudo systemctl restart sshd
    ssh_ceph "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

ssh_ceph "${i}" -t -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 ctl1 ctl1.cloud.atmosphere.dev
10.0.123.12 ctl2 ctl2.cloud.atmosphere.dev
10.0.123.13 ctl3 ctl3.cloud.atmosphere.dev
10.0.123.21 ceph1 ceph1.cloud.atmosphere.dev
10.0.123.22 ceph2 ceph2.cloud.atmosphere.dev
10.0.123.23 ceph3 ceph3.cloud.atmosphere.dev
10.0.123.31 kvm1 kvm1.cloud.atmosphere.dev
10.0.123.32 kvm2 kvm2.cloud.atmosphere.dev
10.0.123.33 kvm3 kvm3.cloud.atmosphere.dev
EOF'

done

for i in {1..3}; do
    until ssh_kvm "${i}" -t -- cloud-init status --wait; do
        sleep 1
    done

    ssh_kvm "${i}" -t -- sudo apt update -y
    ssh_kvm "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils sshpass

    ssh_kvm "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_kvm "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_kvm "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_kvm "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_kvm "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_kvm "${i}" -t -- sudo systemctl restart sshd
    ssh_kvm "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

ssh_kvm "${i}" -t -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 ctl1 ctl1.cloud.atmosphere.dev
10.0.123.12 ctl2 ctl2.cloud.atmosphere.dev
10.0.123.13 ctl3 ctl3.cloud.atmosphere.dev
10.0.123.21 ceph1 ceph1.cloud.atmosphere.dev
10.0.123.22 ceph2 ceph2.cloud.atmosphere.dev
10.0.123.23 ceph3 ceph3.cloud.atmosphere.dev
10.0.123.31 kvm1 kvm1.cloud.atmosphere.dev
10.0.123.32 kvm2 kvm2.cloud.atmosphere.dev
10.0.123.33 kvm3 kvm3.cloud.atmosphere.dev
EOF'

done

ssh_ctl "1" -t -- "sudo sed -i 's/127.0.1.1       ctl1    ctl1/127.0.1.1       ctl1.cloud.atmosphere.dev    ctl1.cloud.atmosphere.dev/' /etc/hosts"
ssh_ctl "2" -t -- "sudo sed -i 's/127.0.1.1       ctl2    ctl2/127.0.1.1       ctl2.cloud.atmosphere.dev    ctl2.cloud.atmosphere.dev/' /etc/hosts"
ssh_ctl "3" -t -- "sudo sed -i 's/127.0.1.1       ctl3    ctl3/127.0.1.1       ctl3.cloud.atmosphere.dev    ctl3.cloud.atmosphere.dev/' /etc/hosts"
ssh_ceph "1" -t -- "sudo sed -i 's/127.0.1.1       ceph1    ceph1/127.0.1.1       ceph1.cloud.atmosphere.dev    ceph1.cloud.atmosphere.dev/' /etc/hosts"
ssh_ceph "2" -t -- "sudo sed -i 's/127.0.1.1       ceph2    ceph2/127.0.1.1       ceph2.cloud.atmosphere.dev    ceph2.cloud.atmosphere.dev/' /etc/hosts"
ssh_ceph "3" -t -- "sudo sed -i 's/127.0.1.1       ceph3    ceph3/127.0.1.1       ceph3.cloud.atmosphere.dev    ceph3.cloud.atmosphere.dev/' /etc/hosts"
ssh_kvm "1" -t -- "sudo sed -i 's/127.0.1.1       kvm1    kvm1/127.0.1.1       kvm1.cloud.atmosphere.dev    kvm1.cloud.atmosphere.dev/' /etc/hosts"
ssh_kvm "2" -t -- "sudo sed -i 's/127.0.1.1       kvm2    kvm2/127.0.1.1       kvm2.cloud.atmosphere.dev    kvm2.cloud.atmosphere.dev/' /etc/hosts"
ssh_kvm "3" -t -- "sudo sed -i 's/127.0.1.1       kvm3    kvm3/127.0.1.1       kvm3.cloud.atmosphere.dev    kvm3.cloud.atmosphere.dev/' /etc/hosts"

for i in {1..3}; do

    ssh_ctl "${i}" -t -- sudo reboot

done

for i in {1..3}; do

    ssh_ceph "${i}" -t -- sudo reboot

done

for i in {1..3}; do

    ssh_kvm "${i}" -t -- sudo reboot

done
