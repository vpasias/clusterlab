#!/bin/bash

TALOS_VERSION="v1.12.1"
CLUSTER_NAME=athena
NODE_IP=192.168.254.21
VIP=192.168.254.254

if [ -f ./controlplane.yaml ] || [ -f ./worker.yaml ] || [ -f ./talosconfig ]; then
    echo "ERROR: Existing configuration detected. 
          
Please remove the following files or work out of a different directory:
        
- controlplane.yaml
- worker.yaml
- talosconfig"
    exit 1
fi

while [[ ! -n $CLUSTER_NAME ]]
do
    read -p "Enter a cluster name: " CLUSTER_NAME
done

while [[ ! -n $NODE_IP ]]
do
    read -p "Enter your first node's IP Address: " NODE_IP
done


while [[ ! -n $VIP ]]
do
    read -p "Enter your cluster's Virtual IP Address: " VIP
done

echo
echo "Is this correct?
Cluster Name: $CLUSTER_NAME
First Node IP: $NODE_IP
VIP: $VIP"
echo
read -p "Y/N: " RESPONSE

if [[ "$RESPONSE" == "Y" ]];then

    echo
    echo "Testing connection to node, please wait..."
    echo
    
    if ping -c 4 $NODE_IP; then
    
        # Get schematic ID and generate initial config file
        SCHEMATIC=$(curl -sX POST --data-binary @schematic.yaml https://factory.talos.dev/schematics)
        SCHEMATICID=$(echo "$SCHEMATIC" | jq '.id' | tr -d '"')
        talosctl gen config $CLUSTER_NAME https://$NODE_IP:6443 --install-disk /dev/vda --install-image=factory.talos.dev/installer/$SCHEMATICID:$TALOS_VERSION

        # Add VIP config to controlplane.yaml
        sed -i '/network: {}/r network-config.yaml' controlplane.yaml && sed -i '/network: {}/d' controlplane.yaml

        # Replace endpoint string with VIP
        sed -i -E "s/(endpoint: https:\/\/)[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:6443)/\1$VIP\2/" controlplane.yaml
        sed -i -E "s/(endpoint: https:\/\/)[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:6443)/\1$VIP\2/" worker.yaml

        # Apply config, bootstrap the cluster and retrieve kubeconfig
        talosctl apply-config --file controlplane.yaml --insecure --nodes 192.168.254.21
        talosctl apply-config --file controlplane.yaml --insecure --nodes 192.168.254.22
        talosctl apply-config --file controlplane.yaml --insecure --nodes 192.168.254.23

        #Add worker nodes:
        talosctl apply-config --file worker.yaml --insecure --nodes 192.168.254.24
        talosctl apply-config --file worker.yaml --insecure --nodes 192.168.254.25
        talosctl apply-config --file worker.yaml --insecure --nodes 192.168.254.26

        #Set your endpoints
        talosctl --talosconfig=./talosconfig config endpoints 192.168.254.21

        #Bootstrap Your Etcd Cluster
        talosctl bootstrap --nodes 192.168.254.21 --talosconfig=./talosconfig
    fi
else
    echo "Exiting script..."
    exit 1
fi
