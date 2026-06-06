#!/bin/bash

# Load parameters from the config file
source nfs-ha-config.txt

# Update and install necessary packages
sudo apt install build-essential linux-headers-$(uname -r) -y
sudo add-apt-repository ppa:linbit/linbit-drbd9-stack -y
sudo apt update && sudo apt -y upgrade
sudo apt -y install drbd-utils drbd-dkms lvm2 nfs-kernel-server corosync pcs pacemaker pwgen resource-agents-extra sysstat

# Disable conflicting NFS services
sudo systemctl disable --now nfs-server rpc-statd

# Load DRBD module
sudo modprobe drbd
echo drbd | sudo tee /etc/modules-load.d/drbd.conf

# Set up /etc/hosts for both nodes
echo "$IP1  $NODE1" | sudo tee -a /etc/hosts
echo "$IP2  $NODE2" | sudo tee -a /etc/hosts
echo "$REPIP1  $NODE1" | sudo tee -a /etc/hosts
echo "$REPIP2  $NODE2" | sudo tee -a /etc/hosts

# Ensure both nodes can communicate
ping -c 3 $REPIP1
ping -c 3 $REPIP2

# Create DRBD configuration file from template
cat drbd-config-template.txt | sed "s/NODE1/$NODE1/g" | sed "s/NODE2/$NODE2/g" | sed "s/REPIP1/$REPIP1/g" | sed "s/REPIP2/$REPIP2/g" > /etc/drbd.d/$DRBDRES.res

# LVM setup on DRBD device
sudo pvcreate $BACKDEV
sudo vgcreate $DRBDVG $BACKDEV
sudo lvcreate -y -l 100%FREE -n $DRBDLV $DRBDVG

# Initialize DRBD
sudo drbdadm --force create-md $DRBDRES
sudo drbdadm up $DRBDRES

# Authenticate PCS between nodes
sudo pcs host auth $NODE1 $NODE2 -u hacluster -p "$PASSWORD"

# Set up and start the Pacemaker cluster
sudo pcs cluster setup --name cluster_nfs $NODE1 $NODE2
sudo pcs cluster start --all
sudo pcs property set stonith-enabled=false
sudo pcs property set no-quorum-policy=ignore

# Create DRBD as promotable resource
sudo pcs resource create nfsserver_data ocf:linbit:drbd drbd_resource=$DRBDRES op monitor interval=60s
sudo pcs resource promotable nfsserver_data master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true

# Ensure DRBD is in primary state
sudo drbdadm primary --force $DRBDRES

# Format the DRBD device and mount it
sudo mkfs.ext4 /dev/$DRBDDEV
sudo mkdir -p $NFSEXPORTDIR
sudo mount /dev/$DRBDDEV $NFSEXPORTDIR

# NFS configuration
sudo pcs resource create nfsfs ocf:heartbeat:Filesystem device=/dev/$DRBDDEV directory=$NFSEXPORTDIR fstype=ext4 --group nfsgrp
sudo pcs constraint colocation add nfsserver_data-clone nfsgrp INFINITY with-rsc-role=Master
sudo pcs constraint order promote nfsserver_data-clone then start nfsgrp
sudo pcs resource create nfsd ocf:heartbeat:nfsserver --group nfsgrp
sudo pcs resource create nfsroot ocf:heartbeat:exportfs clientspec="$NFSCLIENTIP" options=rw,sync,no_root_squash directory=$NFSEXPORTDIR fsid=0 --group nfsgrp
sudo pcs resource create nfsip ocf:heartbeat:IPaddr2 ip=$HAVIP cidr_netmask=32 --group nfsgrp

# Enable Corosync and Pacemaker
sudo systemctl enable --now corosync pacemaker

echo "NFS-HA setup completed."
