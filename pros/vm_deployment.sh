#!/bin/bash

set -eux

kcli create network -c 172.90.0.0/24 service

kcli create network -c 192.168.0.0/24 -P dhcp=false -P dns=false external

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100,100,100,100] -P nets=['{"name":"service","ip":"172.90.0.30","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] ceph0

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100,100,100,100] -P nets=['{"name":"service","ip":"172.90.0.31","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] ceph1

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100,100,100,100] -P nets=['{"name":"service","ip":"172.90.0.32","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] ceph2

kcli create vm -i centos9stream -P memory=16384 -P numcpus=4 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.33","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] infra

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.34","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] controller0

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.35","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] controller1

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.36","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] controller2

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.37","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] compute0

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.38","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] compute1

kcli create vm -i centos9stream -P memory=24576 -P numcpus=6 -P disks=[100] -P nets=['{"name":"service","ip":"172.90.0.39","netmask":"24","gateway":"172.90.0.1"}','{"name":"external"}'] -P cmds=['sudo yum -y update && sudo yum -y install vim chrony sshpass'] compute2

sleep 120

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

kcli ssh ceph1 'sudo tee -a /etc/hosts <<EOF
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

kcli ssh ceph2 'sudo tee -a /etc/hosts <<EOF
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

kcli ssh infra 'sudo tee -a /etc/hosts <<EOF
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

kcli ssh controller0 'sudo tee -a /etc/hosts <<EOF
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

kcli ssh controller1 'sudo tee -a /etc/hosts <<EOF
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

kcli ssh controller2 'sudo tee -a /etc/hosts <<EOF
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

kcli ssh compute0 'sudo tee -a /etc/hosts <<EOF
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

kcli ssh compute1 'sudo tee -a /etc/hosts <<EOF
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

kcli ssh compute2 'sudo tee -a /etc/hosts <<EOF
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

kcli ssh ceph0 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh ceph0 "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh ceph0 "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh ceph0 "sudo systemctl restart sshd"
kcli ssh ceph0 "sudo rm -rf /root/.ssh/authorized_keys"

kcli ssh ceph1 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh ceph1 "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh ceph1 "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh ceph1 "sudo systemctl restart sshd"
kcli ssh ceph1 "sudo rm -rf /root/.ssh/authorized_keys"

kcli ssh ceph2 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh ceph2 "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh ceph2 "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh ceph2 "sudo systemctl restart sshd"
kcli ssh ceph2 "sudo rm -rf /root/.ssh/authorized_keys"

kcli ssh infra 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh infra "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh infra "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh infra "sudo systemctl restart sshd"
kcli ssh infra "sudo rm -rf /root/.ssh/authorized_keys"

kcli ssh controller0 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh controller0 "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh controller0 "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh controller0 "sudo systemctl restart sshd"
kcli ssh controller0 "sudo rm -rf /root/.ssh/authorized_keys"

kcli ssh controller1 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh controller1 "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh controller1 "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh controller1 "sudo systemctl restart sshd"
kcli ssh controller1 "sudo rm -rf /root/.ssh/authorized_keys"

kcli ssh controller2 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh controller2 "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh controller2 "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh controller2 "sudo systemctl restart sshd"
kcli ssh controller2 "sudo rm -rf /root/.ssh/authorized_keys"

kcli ssh compute0 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh compute0 "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh compute0 "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh compute0 "sudo systemctl restart sshd"
kcli ssh compute0 "sudo rm -rf /root/.ssh/authorized_keys"

kcli ssh compute1 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh compute1 "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh compute1 "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh compute1 "sudo systemctl restart sshd"
kcli ssh compute1 "sudo rm -rf /root/.ssh/authorized_keys"

kcli ssh compute2 'echo "root:gprm8350" | sudo chpasswd'
kcli ssh compute2 "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
kcli ssh compute2 "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
kcli ssh compute2 "sudo systemctl restart sshd"
kcli ssh compute2 "sudo rm -rf /root/.ssh/authorized_keys"

kcli list images
kcli list pools
kcli list networks
kcli list vms
