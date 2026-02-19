#!/bin/bash

# Cheat script for a full deployment.
# This should be used for testing only.

set -eu

# Install git and tmux.
if $(which dnf 2>/dev/null >/dev/null); then
    sudo dnf -y install git tmux
else
    sudo apt update
    sudo apt -y install git python3 python3-venv tmux
fi

# Install Python 3.12 on Rocky Linux 9
if $(which dnf 2>/dev/null >/dev/null); then
    sudo dnf -y install python3.12
fi

# Disable the firewall.
sudo systemctl is-enabled firewalld && sudo systemctl stop firewalld && sudo systemctl disable firewalld

# Put SELinux in permissive mode both immediately and permanently.
if $(which setenforce 2>/dev/null >/dev/null); then
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
fi

# Prevent sudo from performing DNS queries.
echo 'Defaults	!fqdn' | sudo tee /etc/sudoers.d/no-fqdn

# Import existing network configuration in systemd-networkd. This prevents
# existing netplan configuration (e.g. for a DHCP-configured interface) from
# being disabled by kayobe.
if command -v apt >/dev/null 2>&1; then
    sudo find /run/systemd/network -mindepth 1 -maxdepth 1 -exec cp -t /etc/systemd/network/ {} +
    sudo find /etc/systemd/network -mindepth 1 -maxdepth 1 -exec chown root:systemd-network {} +
fi

# Start at home.
cd

# Clone Beokay.
[[ -d beokay ]] || git clone https://github.com/stackhpc/beokay.git

# Use Beokay to bootstrap your control host.
if $(which dnf 2>/dev/null >/dev/null); then
    PYTHON_ARG=" --python /usr/bin/python3.12"
else
    PYTHON_ARG=""
fi
[[ -d deployment ]] || beokay/beokay.py create --base-path ~/deployment --kayobe-repo https://opendev.org/openstack/kayobe.git --kayobe-branch stable/2025.1 --kayobe-config-repo https://github.com/stackhpc/a-universe-from-nothing.git --kayobe-config-branch stable/2025.1 $PYTHON_ARG

rm -rf ~/deployment/src/kayobe-config/tenks.yml

tee > ~/deployment/src/kayobe-config/tenks.yml <<EOF
---
# This file holds the config given to Tenks when running `tenks-deploy.sh`. It
# assumes the existence of the bridge `braio`.

node_types:
  controller:
    memory_mb: 32768
    vcpus: 8
    volumes:
      # There is a minimum disk space capacity requirement of 4GiB when using Ironic Python Agent:
      # https://github.com/openstack/ironic-python-agent/blob/master/ironic_python_agent/utils.py#L290
      - capacity: 100GiB
    physical_networks:
      - physnet1
    console_log_enabled: true
  compute:
    memory_mb: 311296
    vcpus: 48
    volumes:
      # There is a minimum disk space capacity requirement of 4GiB when using Ironic Python Agent:
      # https://github.com/openstack/ironic-python-agent/blob/master/ironic_python_agent/utils.py#L290
      - capacity: 900GiB
    physical_networks:
      - physnet1
    console_log_enabled: true

specs:
  - type: controller
    count: 1
    node_name_prefix: controller
    ironic_config:
      resource_class: test-rc
      network_interface: noop
  - type: compute
    count: 1
    node_name_prefix: compute
    ironic_config:
      resource_class: test-rc
      network_interface: noop

ipmi_address: 192.168.33.4

nova_flavors: []

physnet_mappings:
  physnet1: braio

bridge_type: linuxbridge

# No placement service.
wait_for_placement: false

# NOTE(priteau): Disable libvirt_vm_trust_guest_rx_filters, which when enabled
# triggers the following errors when booting baremetal instances with Tenks on
# Libvirt 9: Cannot set interface flags on 'macvtap1': Value too large for
# defined data type
libvirt_vm_trust_guest_rx_filters: false
EOF

# Clone the Tenks repository.
cd ~/deployment/src
[[ -d tenks ]] || git clone https://opendev.org/openstack/tenks.git

# Configure host networking (bridge, routes & firewall)
./kayobe-config/configure-local-networking.sh

# Use the kayobe virtual environment, and export kayobe environment variables
source ~/deployment/env-vars.sh

# Configure the seed hypervisor host.
kayobe seed hypervisor host configure

# Provision the seed VM.
kayobe seed vm provision

# Configure the seed host, and deploy a local registry.
kayobe seed host configure

# Pull, retag images, then push to our local registry.
~/deployment/src/kayobe-config/pull-retag-push-images.sh

# Deploy the seed services.
kayobe seed service deploy

# Deploying the seed restarts networking interface,
# run configure-local-networking.sh again to re-add routes.
~/deployment/src/kayobe-config/configure-local-networking.sh

sudo virsh list --all

# Set Environment variables for Kayobe dev scripts
export KAYOBE_CONFIG_SOURCE_PATH=~/deployment/src/kayobe-config
export KAYOBE_VENV_PATH=~/deployment/venvs/kayobe
export TENKS_CONFIG_PATH=~/deployment/src/kayobe-config/tenks.yml

# Deploy overcloud using Tenks
~/deployment/src/kayobe/dev/tenks-deploy-overcloud.sh ~/deployment/src/tenks

# Inspect and provision the overcloud hardware:
kayobe overcloud inventory discover
kayobe overcloud hardware inspect
kayobe overcloud introspection data save
kayobe overcloud provision
kayobe overcloud host configure
kayobe overcloud container image pull
kayobe overcloud service deploy
source ~/deployment/src/kayobe-config/etc/kolla/public-openrc.sh
kayobe overcloud post configure
source ~/deployment/src/kayobe-config/etc/kolla/public-openrc.sh
~/deployment/src/kayobe-config/init-runonce.sh
