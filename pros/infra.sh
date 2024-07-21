kcli create network -c 172.90.0.0/24 service

kcli create network -c 172.90.1.0/24 external

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100,'{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"}'] -P nets=['{"name":"service","ip":"172.90.0.30","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony '] ceph0

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100,'{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"}'] -P nets=['{"name":"service","ip":"172.90.0.31","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony '] ceph1

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100,'{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"} ','{"size": 100, "interface": "sata"}'] -P nets=['{"name":"service","ip":"172.90.0.32","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony '] ceph2

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.33","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] deploy

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.34","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] controller0

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.35","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] controller1

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.36","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] controller2

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.37","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] compute0

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.38","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] compute1

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.39","netmask":"24","gateway":"172.90.0.1"}',external] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony'] compute2
