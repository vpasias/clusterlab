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

function ssh_ctl() {
    local ip="172.19.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

function ssh_osctl() {
    local ip="172.19.123.2${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

function ssh_oscomp() {
    local ip="172.19.123.3${1}"
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
        "oc-virtual-lab-server-ctl-0${i}" \
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
EOF
done

for i in {1..3}; do
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
        "oc-virtual-lab-server-os-ctl-0${i}" \
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
EOF
done

for i in {1..3}; do
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
        "oc-virtual-lab-server-os-cmp-0${i}" \
        release=noble
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 172.19.123.3${i}/24
      routes:
        - to: default
          via: 172.19.123.1
      nameservers:
        addresses:
          - 172.19.123.1
EOF
done

for i in {1..3}; do
    virsh detach-interface "oc-virtual-lab-server-ctl-0${i}" network --config    
    virsh attach-interface "oc-virtual-lab-server-ctl-0${i}" network virbr-mgt --model virtio --config
    virsh start "oc-virtual-lab-server-ctl-0${i}"
done

for i in {1..3}; do
    virsh detach-interface "oc-virtual-lab-server-os-ctl-0${i}" network --config    
    virsh attach-interface "oc-virtual-lab-server-os-ctl-0${i}" network virbr-mgt --model virtio --config    
    virsh start "oc-virtual-lab-server-os-ctl-0${i}"
done

for i in {1..3}; do
    virsh detach-interface "oc-virtual-lab-server-os-cmp-0${i}" network --config
    virsh attach-interface "oc-virtual-lab-server-os-cmp-0${i}" network virbr-mgt --model virtio --config
    virsh start "oc-virtual-lab-server-os-cmp-0${i}"
done

sleep 30

for i in {1..3}; do

    ssh_ctl "${i}" -t -- sudo apt update -y
    ssh_ctl "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils sshpass

    ssh_ctl "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_ctl "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_ctl "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_ctl "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_ctl "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_ctl "${i}" -t -- sudo systemctl restart ssh
    ssh_ctl "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

ssh_ctl "${i}" -t -- 'sudo tee -a /etc/hosts <<EOF
172.19.123.11 oc-virtual-lab-server-ctl-01
172.19.123.12 oc-virtual-lab-server-ctl-02
172.19.123.13 oc-virtual-lab-server-ctl-03
172.19.123.21 oc-virtual-lab-server-os-ctl-01
172.19.123.22 oc-virtual-lab-server-os-ctl-02
172.19.123.23 oc-virtual-lab-server-os-ctl-03
172.19.123.31 oc-virtual-lab-server-os-cmp-01
172.19.123.32 oc-virtual-lab-server-os-cmp-02
172.19.123.33 oc-virtual-lab-server-os-cmp-03
EOF'

done

for i in {1..3}; do

    ssh_osctl "${i}" -t -- sudo apt update -y
    ssh_osctl "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils sshpass

    ssh_osctl "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_osctl "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_osctl "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_osctl "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_osctl "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_osctl "${i}" -t -- sudo systemctl restart ssh
    ssh_osctl "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

ssh_osctl "${i}" -t -- 'sudo tee -a /etc/hosts <<EOF
172.19.123.11 oc-virtual-lab-server-ctl-01
172.19.123.12 oc-virtual-lab-server-ctl-02
172.19.123.13 oc-virtual-lab-server-ctl-03
172.19.123.21 oc-virtual-lab-server-os-ctl-01
172.19.123.22 oc-virtual-lab-server-os-ctl-02
172.19.123.23 oc-virtual-lab-server-os-ctl-03
172.19.123.31 oc-virtual-lab-server-os-cmp-01
172.19.123.32 oc-virtual-lab-server-os-cmp-02
172.19.123.33 oc-virtual-lab-server-os-cmp-03
EOF'

done

for i in {1..3}; do

    ssh_oscomp "${i}" -t -- sudo apt update -y
    ssh_oscomp "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils sshpass

    ssh_oscomp "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_oscomp "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_oscomp "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_oscomp "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_oscomp "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_oscomp "${i}" -t -- sudo systemctl restart ssh
    ssh_oscomp "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

ssh_oscomp "${i}" -t -- 'sudo tee -a /etc/hosts <<EOF
172.19.123.11 oc-virtual-lab-server-ctl-01
172.19.123.12 oc-virtual-lab-server-ctl-02
172.19.123.13 oc-virtual-lab-server-ctl-03
172.19.123.21 oc-virtual-lab-server-os-ctl-01
172.19.123.22 oc-virtual-lab-server-os-ctl-02
172.19.123.23 oc-virtual-lab-server-os-ctl-03
172.19.123.31 oc-virtual-lab-server-os-cmp-01
172.19.123.32 oc-virtual-lab-server-os-cmp-02
172.19.123.33 oc-virtual-lab-server-os-cmp-03
EOF'

done

for i in {1..3}; do

    ssh_ctl "${i}" -t -- sudo reboot

done

for i in {1..3}; do

    ssh_osctl "${i}" -t -- sudo reboot

done

for i in {1..3}; do

    ssh_oscomp "${i}" -t -- sudo reboot

done
