#!/bin/bash

# --- Configuration Variables ---
VM_NAME="cif"
RAM=344064 # In MB (4GB)
VCPUS=60
DISK_SIZE=1300 # In GB
ISO_PATH="/mnt/extra/virt/CentOS-Stream-9-latest-x86_64-boot.iso"
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
BRIDGE="service"

echo "Creating VM: ${VM_NAME}..."

# --- Create Virtual Disk ---
qemu-img create -f qcow2 ${DISK_PATH} ${DISK_SIZE}G

# --- Create VM with virt-install ---
virt-install \
  --name=${VM_NAME} \
  --ram=${RAM} \
  --vcpus=${VCPUS} \
  --disk path=${DISK_PATH},format=qcow2,bus=virtio \
  --os-variant=centos-stream9 \
  --network bridge=${BRIDGE},model=virtio \
  --graphics none \
  --cdrom=${ISO_PATH} \
  --boot hd,cdrom \
  --console pty,target_type=serial \
  --extra-args 'console=ttyS0,115200n8'

echo "VM ${VM_NAME} creation initiated."
echo "Use 'virsh list' to check status."
