#!/bin/bash
set -eux

echo "root:gprm8350" | sudo chpasswd
#sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
#sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
#sudo systemctl restart sshd
#sudo rm -rf /root/.ssh/authorized_keys

sudo apt update -y && sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils gcc

sudo chmod -x /etc/update-motd.d/*

cat << EOF | sudo tee /etc/update-motd.d/01-custom
#!/bin/sh
echo "****************************WARNING****************************************
UNAUTHORISED ACCESS IS PROHIBITED. VIOLATORS WILL BE PROSECUTED.
*********************************************************************************"
EOF

sudo chmod +x /etc/update-motd.d/01-custom

cat << EOF | sudo tee /etc/modprobe.d/qemu-system-x86.conf
options kvm_intel nested=1
EOF

sudo modprobe -r kvm_intel

sudo modprobe kvm_intel nested=1

cat /sys/module/kvm_intel/parameters/nested

sudo modinfo kvm_intel | grep -i nested

sudo mkdir -p /etc/apt/sources.list.d

sudo swapoff -a

sudo apt update -y

sudo lsblk -f
uname -a
