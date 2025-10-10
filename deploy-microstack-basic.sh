#!/bin/bash

set -eux

cd "$(dirname "$0")"

cat <<EOF | virsh net-define /dev/stdin
<network>
  <name>virbr-sunbeam</name>
  <bridge name='virbr-sunbeam' stp='off'/>
  <forward mode='nat'/>
  <ip address='10.0.123.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='10.0.123.241' end='10.0.123.254'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-autostart virbr-sunbeam && virsh net-start virbr-sunbeam

## clean up
for i in {1..5}; do
    # FIXME: the requirement of FQDN is not documented well in each tutorial
    uvt-kvm destroy "node-${i}.localdomain" || true
done

function ssh_to() {
    local ip="10.0.123.1${1}"
    shift
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu "${ip}" "$@"
}

for i in {1..5}; do
    cat <<EOF | uvt-kvm create \
        --machine-type q35 \
        --cpu 16 \
        --host-passthrough \
        --memory 32768 \
        --disk 200 \
        --ephemeral-disk 200 \
        --ephemeral-disk 200 \
        --unsafe-caching \
        --network-config /dev/stdin \
        --ssh-public-key-file ~/.ssh/id_ed25519.pub \
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
        - 10.0.123.1${i}/24
      routes:
        - to: default
          via: 10.0.123.1
      nameservers:
        addresses:
          - 10.0.123.1
EOF
done

for i in {1..5}; do
    virsh detach-interface "node-${i}.localdomain" network --config

    virsh attach-interface "node-${i}.localdomain" network virbr-sunbeam \
        --model virtio --config
    virsh attach-interface "node-${i}.localdomain" network virbr-sunbeam \
        --model virtio --config

    virsh start "node-${i}.localdomain"
done

for i in {1..5}; do
     until ssh_to "${i}" -t -- 'systemctl is-system-running --wait; ip -br a; lsblk'; do
     sleep 5
     done
done

for i in {1..5}; do

    ssh_to "${i}" -t -- sudo apt update -y
    ssh_to "${i}" -t -- sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils iperf mtr traceroute netcat-traditional sshpass socat

    ssh_to "${i}" -t -- 'echo "root:gprm8350" | sudo chpasswd'
    ssh_to "${i}" -t -- 'echo "ubuntu:kyax7344" | sudo chpasswd'
    ssh_to "${i}" -t -- "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    ssh_to "${i}" -t -- "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    ssh_to "${i}" -t -- sudo systemctl restart ssh
    ssh_to "${i}" -t -- sudo rm -rf /root/.ssh/authorized_keys

    ssh_to "${i}" -t -- 'sudo install -m 0600 /dev/stdin /etc/netplan/90-local-ovs-ext-port.yaml <<EOF
          network:
            version: 2
            ethernets:
              # LP: #2065911
              enp9s0:
                dhcp4: false
                dhcp6: false
                accept-ra: false
          EOF
          sudo netplan apply'
    
done

ssh_to 1 -t -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 node-1 node-1.localdomain
10.0.123.12 node-2 node-2.localdomain
10.0.123.13 node-3 node-3.localdomain
10.0.123.14 node-4 node-4.localdomain
10.0.123.15 node-5 node-5.localdomain
EOF'

ssh_to 2 -t -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 node-1 node-1.localdomain
10.0.123.12 node-2 node-2.localdomain
10.0.123.13 node-3 node-3.localdomain
10.0.123.14 node-4 node-4.localdomain
10.0.123.15 node-5 node-5.localdomain
EOF'

ssh_to 3 -t -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 node-1 node-1.localdomain
10.0.123.12 node-2 node-2.localdomain
10.0.123.13 node-3 node-3.localdomain
10.0.123.14 node-4 node-4.localdomain
10.0.123.15 node-5 node-5.localdomain
EOF'

ssh_to 4 -t -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 node-1 node-1.localdomain
10.0.123.12 node-2 node-2.localdomain
10.0.123.13 node-3 node-3.localdomain
10.0.123.14 node-4 node-4.localdomain
10.0.123.15 node-5 node-5.localdomain
EOF'

ssh_to 5 -t -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 node-1 node-1.localdomain
10.0.123.12 node-2 node-2.localdomain
10.0.123.13 node-3 node-3.localdomain
10.0.123.14 node-4 node-4.localdomain
10.0.123.15 node-5 node-5.localdomain
EOF'

for i in {1..5}; do

    ssh_to "${i}" -t -- sudo snap install openstack --channel 2024.1/edge
    ssh_to "${i}" -t -- 'sunbeam prepare-node-script | bash -x'

# LP: #2065911
# TODO: make it permanent across reboots
#    ssh_to "${i}" -t -- sudo ip link set enp9s0 up
done

ssh_to 1 -t -- 'tee deployment_manifest.yaml' < umanifest.yaml
#ssh_to 1 -t -- 'tail -n+2 /snap/openstack/current/etc/manifests/edge.yml >> deployment_manifest.yaml'
