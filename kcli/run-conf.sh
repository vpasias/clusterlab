#! /bin/sh

export LC_ALL=C
export LC_CTYPE="UTF-8",
export LANG="en_US.UTF-8"

echo 'run-conf.sh: Install sshpass & nfs-common'
for i in {7..9}; do ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.1$i 'sudo apt -y install nfs-common sshpass'; done

echo 'run-conf.sh: Running node setup'
for i in {7..9}; do ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.1$i 'git clone https://github.com/vpasias/clusterlab.git && sudo bash /home/ubuntu/clusterlab/kcli/snode_setup.sh'; done

sleep 30

echo 'run-conf.sh: Configuration of GlusterFS'

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo systemctl status glusterd"
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo gluster peer probe n8"
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo gluster peer probe n9"

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo gluster peer status"
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.18 "sudo gluster peer status"
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.19 "sudo gluster peer status"

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo gluster volume create sharedvol replica 3 n7:/data/glusterfs/sharedvol/mybrick/brick \
n8:/data/glusterfs/sharedvol/mybrick/brick \
n9:/data/glusterfs/sharedvol/mybrick/brick"

sleep 10

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo gluster volume start sharedvol"

sleep 10

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo gluster volume info"

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo gluster volume status"

echo 'run-conf.sh: GlusterFS configuration finished'

echo 'run-conf.sh: Configure Pacemaker'

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 'echo "hacluster:gprm8350" | sudo chpasswd'
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.18 'echo "hacluster:gprm8350" | sudo chpasswd'
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.19 'echo "hacluster:gprm8350" | sudo chpasswd'

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo systemctl enable corosync && sudo systemctl enable pacemaker && sudo systemctl enable --now pcsd"
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.18 "sudo systemctl enable corosync && sudo systemctl enable pacemaker && sudo systemctl enable --now pcsd"
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.19 "sudo systemctl enable corosync && sudo systemctl enable pacemaker && sudo systemctl enable --now pcsd"

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo systemctl stop corosync"
sleep 10
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo systemctl stop pacemaker"

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.18 "sudo systemctl stop corosync"
sleep 10
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.18 "sudo systemctl stop pacemaker"

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.19 "sudo systemctl stop corosync"
sleep 10
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.19 "sudo systemctl stop pacemaker"

sleep 20

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo systemctl status pacemaker"
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo systemctl status corosync"

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo rm -rf /etc/corosync/corosync.conf"

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo pcs host auth -u hacluster -p gprm8350 n7 n8 n9"
sleep 5
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo pcs cluster setup HA-NFS n7 n8 n9 --force"
sleep 5
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo pcs cluster start --all"
sleep 5
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo pcs cluster enable --all"
sleep 5
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo pcs property set stonith-enabled=false"
sleep 5
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo pcs resource create nfs_server systemd:nfs-ganesha op monitor interval=10s"
sleep 5
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo pcs resource create nfs_ip ocf:heartbeat:IPaddr2 ip=10.0.123.5 cidr_netmask=24 op monitor interval=10s"
sleep 5
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo pcs resource group add nfs_group nfs_server nfs_ip"
sleep 5
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l ubuntu 10.0.123.17 "sudo pcs status"

echo 'run-conf.sh: Pacemaker configuration finished'