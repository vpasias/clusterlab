#!/bin/bash

set -eux

cd "$(dirname "$0")"

cat <<EOF | virsh net-define /dev/stdin
<network>
  <name>virbr-mgt</name>
  <bridge name='virbr-mgt' stp='off'/>
  <forward mode='nat'/>
  <ip address='10.0.123.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

sudo virsh net-autostart virbr-mgt
sudo virsh net-start virbr-mgt

function ssh_to() {
    local ip="10.0.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..9}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 6 \
        --host-passthrough \
        --memory 24576 \
        --disk 100 \
        --ephemeral-disk 100 \
        --ephemeral-disk 100 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --no-start \
        "n${i}" \
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

for i in {1..9}; do
    virsh detach-interface "n${i}" network --config

    virsh attach-interface "n${i}" network virbr-mgt \
        --model virtio --config

    virsh start "n${i}"
done


for i in {1..9}; do
    until ssh_to "${i}" -t -- cloud-init status --wait; do
        sleep 1
    done

    ssh_to "${i}" -t -- sudo apt update -y
    ssh_to "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils iperf iperf3 mtr traceroute netcat sshpass socat

    ssh_to "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_to "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_to "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_to "${i}" -t -- sudo systemctl restart sshd
    ssh_to "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

done

ssh_to 1 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 n1 mon1 mgr1
10.0.123.12 n2 mon2 mgr2
10.0.123.13 n3 mon3 mgr3
10.0.123.14 n4
10.0.123.15 n5
10.0.123.16 n6
10.0.123.17 n7 osd1
10.0.123.18 n8 osd2
10.0.123.19 n9 osd3
EOF'

ssh_to 2 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 n1 mon1 mgr1
10.0.123.12 n2 mon2 mgr2
10.0.123.13 n3 mon3 mgr3
10.0.123.14 n4
10.0.123.15 n5
10.0.123.16 n6
10.0.123.17 n7 osd1
10.0.123.18 n8 osd2
10.0.123.19 n9 osd3
EOF'

ssh_to 3 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 n1 mon1 mgr1
10.0.123.12 n2 mon2 mgr2
10.0.123.13 n3 mon3 mgr3
10.0.123.14 n4
10.0.123.15 n5
10.0.123.16 n6
10.0.123.17 n7 osd1
10.0.123.18 n8 osd2
10.0.123.19 n9 osd3
EOF'

ssh_to 4 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 n1 mon1 mgr1
10.0.123.12 n2 mon2 mgr2
10.0.123.13 n3 mon3 mgr3
10.0.123.14 n4
10.0.123.15 n5
10.0.123.16 n6
10.0.123.17 n7 osd1
10.0.123.18 n8 osd2
10.0.123.19 n9 osd3
EOF'

ssh_to 5 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 n1 mon1 mgr1
10.0.123.12 n2 mon2 mgr2
10.0.123.13 n3 mon3 mgr3
10.0.123.14 n4
10.0.123.15 n5
10.0.123.16 n6
10.0.123.17 n7 osd1
10.0.123.18 n8 osd2
10.0.123.19 n9 osd3
EOF'

ssh_to 6 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 n1 mon1 mgr1
10.0.123.12 n2 mon2 mgr2
10.0.123.13 n3 mon3 mgr3
10.0.123.14 n4
10.0.123.15 n5
10.0.123.16 n6
10.0.123.17 n7 osd1
10.0.123.18 n8 osd2
10.0.123.19 n9 osd3
EOF'

ssh_to 7 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 n1 mon1 mgr1
10.0.123.12 n2 mon2 mgr2
10.0.123.13 n3 mon3 mgr3
10.0.123.14 n4
10.0.123.15 n5
10.0.123.16 n6
10.0.123.17 n7 osd1
10.0.123.18 n8 osd2
10.0.123.19 n9 osd3
EOF'

ssh_to 8 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 n1 mon1 mgr1
10.0.123.12 n2 mon2 mgr2
10.0.123.13 n3 mon3 mgr3
10.0.123.14 n4
10.0.123.15 n5
10.0.123.16 n6
10.0.123.17 n7 osd1
10.0.123.18 n8 osd2
10.0.123.19 n9 osd3
EOF'

ssh_to 9 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 n1 mon1 mgr1
10.0.123.12 n2 mon2 mgr2
10.0.123.13 n3 mon3 mgr3
10.0.123.14 n4
10.0.123.15 n5
10.0.123.16 n6
10.0.123.17 n7 osd1
10.0.123.18 n8 osd2
10.0.123.19 n9 osd3
EOF'

for i in {1..9}; do

    ssh_to "${i}" -t -- sudo reboot

done
