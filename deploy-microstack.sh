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

ssh_to 1 -- 'sudo tee -a /etc/hosts <<EOF
10.0.123.11 node-1 node-1.localdomain
10.0.123.12 node-2 node-2.localdomain
10.0.123.13 node-3 node-3.localdomain
10.0.123.14 node-4 node-4.localdomain
10.0.123.15 node-5 node-5.localdomain
EOF'

ssh_to 1 -- 'ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""'

ssh_to 1 -- ssh-copy-id -p kyax7344 ubuntu@node-1
ssh_to 1 -- ssh-copy-id -p kyax7344 ubuntu@node-2
ssh_to 1 -- ssh-copy-id -p kyax7344 ubuntu@node-3
ssh_to 1 -- ssh-copy-id -p kyax7344 ubuntu@node-4
ssh_to 1 -- ssh-copy-id -p kyax7344 ubuntu@node-5

for i in {1..5}; do

    ssh_to "${i}" -t -- sudo snap install openstack --channel 2024.1/edge
    ssh_to "${i}" -t -- 'sunbeam prepare-node-script | bash -x'

# LP: #2065911
# TODO: make it permanent across reboots
#    ssh_to "${i}" -- sudo ip link set enp9s0 up
done

ssh_to 1 -- 'tee deployment_manifest.yaml' < umanifest.yaml
#ssh_to 1 -- 'tail -n+2 /snap/openstack/current/etc/manifests/edge.yml >> deployment_manifest.yaml'

ssh_to 1 -t -- \
    time sunbeam cluster bootstrap --manifest deployment_manifest.yaml \
        --role control --role compute --role storage

ssh_to 1 -t -- juju destroy-controller localhost-localhost --no-prompt
ssh_to 1 -t -- lxc profile device remove default eth0
ssh_to 1 -t -- lxc network delete sunbeambr0

# LP: #2065490
ssh_to 1 -- 'juju model-default --cloud sunbeam-microk8s logging-config="<root>=INFO;unit=DEBUG"'
ssh_to 1 -- 'juju model-config -m openstack logging-config="<root>=INFO;unit=DEBUG"'
ssh_to 1 -- sunbeam configure --openrc demo-openrc

ssh_to 1 -- sunbeam cluster add --name node-2.localdomain --output node-2.asc
ssh_to 1 -- sunbeam cluster add --name node-3.localdomain --output node-3.asc
ssh_to 1 -- sunbeam cluster add --name node-4.localdomain --output node-4.asc
ssh_to 1 -- sunbeam cluster add --name node-4.localdomain --output node-5.asc

ssh_to 1 -t -- scp "node2.asc" "ubuntu@node-2:"
ssh_to 1 -t -- scp "node3.asc" "ubuntu@node-3:"
ssh_to 1 -t -- scp "node4.asc" "ubuntu@node-4:"
ssh_to 1 -t -- scp "node5.asc" "ubuntu@node-5:"

ssh_to 2 -t -- \
    time "cat 'node-2.asc' | sunbeam cluster join --role control,compute,storage -"

ssh_to 3 -t -- \
    time "cat 'node-3.asc' | sunbeam cluster join --role control,compute,storage -"

ssh_to 4 -t -- \
    time "cat 'node-4.asc' | sunbeam cluster join --role compute,storage -"

ssh_to 5 -t -- \
    time "cat 'node-5.asc' | sunbeam cluster join --role compute,storage -"

ssh_to 1 -t -- \
    time sunbeam cluster resize

ssh_to 1 -t -- sunbeam launch ubuntu --name test

sleep 5m
ssh_to 1 -t -- '
    set -ex
    source demo-openrc
    demo_floating_ip="$(openstack floating ip list -c Floating\ IP\ Address -f value | head -n1)"
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ~/snap/openstack/current/sunbeam "ubuntu@${demo_floating_ip}" -- systemctl is-system-running --wait
'

for i in {1..5}; do
    ssh_to "${i}" -t -- \
        'time sunbeam openrc > admin-openrc'
done

for i in {1..5}; do
    ssh_to "${i}" -t -- '
        set -x 
        mkdir logs
        cd logs/
        rsync -arv ~/snap/openstack/common/logs/ snap_openstack_common_logs/
        cp -v ../tempest-validation*.log .
        snap list | tee snap_list.txt
        sunbeam cluster list | tee sunbeam_cluster_list.txt
        sudo microceph status | tee microceph_status.txt
        sudo microceph disk list | tee microceph_disk_list.txt
        sudo ceph status | tee ceph_status.txt
        sudo ceph health detail | tee ceph_health_detail.txt
        sudo ceph osd pool autoscale-status | tee ceph_autoscale_status.txt
        sudo k8s status | tee k8s_status.txt
        sudo k8s kubectl get pod -A -o custom-columns=PodName:.metadata.name,PodUID:.metadata.uid > k8s_kubectl_get_pod_-A_custom.txt
        sudo k8s kubectl get all -A > k8s_kubectl_get_all_-A.txt
        sudo k8s kubectl describe all -A > k8s_kubectl_describe_all_-A.txt
        systemd-cgtop -c --cpu=time -1 > systemd-cgtop_-c_--cpu_time_-1.txt
        systemd-cgtop -m -1 > systemd-cgtop_-m_-1.txt
        juju controllers --refresh | tee juju_controllers.txt
        mkdir juju/
        for model in $(juju models --format json | jq -r .models[].name); do
            juju status -m "$model" --relations > "juju/status_${model##*/}.txt"
            juju status -m "$model" --color | tee "juju/status_${model##*/}_color.txt"
            juju debug-log -m "$model" --date --replay > "juju/debug_${model##*/}.log"
        done
        '
         rsync -ar --mkpath "node-${i}.localdomain:logs/" "logs/node-${i}.localdomain"
done

# be nice to my SSD
#ssh_to 1 -t -- juju model-config -m openstack update-status-hook-interval=2h
