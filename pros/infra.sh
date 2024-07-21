#!/bin/bash

set -eux

kcli create network -c 172.90.0.0/24 service

kcli create network -c 172.90.1.0/24 external

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100,'{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"}'] -P nets=['{"name":"service","ip":"172.90.0.30","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony '] ceph0

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100,'{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"}'] -P nets=['{"name":"service","ip":"172.90.0.31","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony '] ceph1

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100,'{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"}'] -P nets=['{"name":"service","ip":"172.90.0.32","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony '] ceph2

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.33","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] infra

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.34","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] controller0

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.35","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] controller1

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.36","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] controller2

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.37","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] compute0

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.38","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] compute1

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.39","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] compute2

kcli ssh ceph0 'sudo tee -a /etc/hosts <<EOF
172.90.0.30 ceph0.vipnet.vip ceph0
172.90.0.31 ceph1.vipnet.vip ceph1
172.90.0.32 ceph2.vipnet.vip ceph2
172.90.0.33 infra.vipnet.vip infra
172.90.0.34 controller0.vipnet.vip controller0
172.90.0.35 controller1.vipnet.vip controller1
172.90.0.36 controller2.vipnet.vip controller2
172.90.0.37 compute0.vipnet.vip compute0
172.90.0.38 compute1.vipnet.vip compute1
172.90.0.39 compute2.vipnet.vip compute2
EOF'
