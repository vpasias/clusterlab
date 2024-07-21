#Run on ceph0. Update Below Hostnames and IPs according to your infra 

cephadm bootstrap --mon-ip 172.90.0.30 --initial-dashboard-user "ceph-admin" --initial-dashboard-password "ADMIN_123" --dashboard-password-noupdate --cluster-network=172.91.0.0/24 --allow-fqdn-hostname


ssh-copy-id -f -i /etc/ceph/ceph.pub root@ceph1
ssh-copy-id -f -i /etc/ceph/ceph.pub root@ceph2


ceph orch host add ceph1.vipnet.vip 172.90.0.31
ceph orch host add ceph2.vipnet.vip 172.90.0.32


ceph orch apply mon --placement="ceph0.vipnet.vip,ceph1.vipnet.vip,ceph2.vipnet.vip"
ceph orch apply mgr --placement="ceph0.vipnet.vip,ceph1.vipnet.vip,ceph2.vipnet.vip"


ceph orch host label add ceph0.vipnet.vip osd-node
ceph orch host label add ceph1.vipnet.vip osd-node
ceph orch host label add ceph2.vipnet.vip osd-node


ceph orch host label add ceph0.vipnet.vip mon
ceph orch host label add ceph1.vipnet.vip mon
ceph orch host label add ceph2.vipnet.vip mon


ceph orch host label add ceph0.vipnet.vip mgr
ceph orch host label add ceph1.vipnet.vip mgr
ceph orch host label add ceph2.vipnet.vip mgr


ceph orch apply osd --all-available-devices
