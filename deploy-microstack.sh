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
      <range start='10.0.123.101' end='10.0.123.254'/>
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
        --bridge virbr-sunbeam \
        --network-config /dev/stdin \
        --ssh-public-key-file ~/.ssh/id_ed25519.pub \
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


for i in {1..5}; do
    virsh detach-interface "node-${i}.localdomain" network --config

    virsh attach-interface "node-${i}.localdomain" network virbr-sunbeam \
        --model virtio --config
    virsh attach-interface "node-${i}.localdomain" network virbr-sunbeam \
        --model virtio --config

    virsh start "node-${i}.localdomain"
done


for i in {1..5}; do
    until ssh_to "${i}" -t -- cloud-init status --wait; do
        sleep 5
    done

    ssh_to "${i}" -t -- sudo snap install openstack --channel 2024.1/edge
    ssh_to "${i}" -t -- 'sunbeam prepare-node-script | bash -x'

    # LP: #2065911
    # TODO: make it permanent across reboots
    ssh_to "${i}" -- sudo ip link set enp9s0 up
done

ssh_to 1 -- 'tee deployment_manifest.yaml' < umanifest.yaml
#ssh_to 1 -- 'tail -n+2 /snap/openstack/current/etc/manifests/edge.yml >> deployment_manifest.yaml'

ssh_to 1 -t -- \
    time sunbeam cluster bootstrap --manifest deployment_manifest.yaml \
        --role control --role compute --role storage

# LP: #2065490
ssh_to 1 -- 'juju model-default --cloud sunbeam-microk8s logging-config="<root>=INFO;unit=DEBUG"'
ssh_to 1 -- 'juju model-config -m openstack logging-config="<root>=INFO;unit=DEBUG"'

ssh_to 1 -- sunbeam cluster add --name node-2.localdomain --output node-2.asc
ssh_to 1 -- sunbeam cluster add --name node-3.localdomain --output node-3.asc
ssh_to 1 -- sunbeam cluster add --name node-4.localdomain --output node-4.asc
ssh_to 1 -- sunbeam cluster add --name node-4.localdomain --output node-5.asc

ssh_to 1 -- scp "node2.asc" "node-2.localdomain:"
ssh_to 1 -- scp "node3.asc" "node-3.localdomain:"
ssh_to 1 -- scp "node4.asc" "node-4.localdomain:"
ssh_to 1 -- scp "node5.asc" "node-5.localdomain:"

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

ssh_to 1 -t -- \
    time sunbeam configure --openrc demo-openrc --manifest deployment_manifest.yaml

for i in {1..5}; do
    ssh_to "${i}" -t -- \
        'time sunbeam openrc > admin-openrc'
done

ssh_to 1 -t -- \
    time sunbeam launch ubuntu --name test

# shellcheck disable=SC2016
ssh_to 1 -t -- '
    set -ex
    # The cloud-init process inside the VM takes ~2 minutes to bring up the
    # SSH service after the VM gets ACTIVE in OpenStack
    sleep 300
    source demo-openrc
    demo_floating_ip="$(openstack floating ip list -c Floating\ IP\ Address -f value | head -n1)"
    ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ~/snap/openstack/current/sunbeam "ubuntu@${demo_floating_ip}" true
'

# be nice to my SSD
ssh_to 1 -t -- juju model-config -m openstack update-status-hook-interval=2h
