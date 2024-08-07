sed -i $'s/\t//g' /etc/kolla/config/cinder/cinder-backup/ceph.conf
sed -i $'s/\t//g' /etc/kolla/config/cinder/cinder-volume/ceph.conf
sed -i $'s/\t//g' /etc/kolla/config/glance/ceph.conf
sed -i $'s/\t//g' /etc/kolla/config/nova/ceph.conf
cd /etc/kolla 
kolla-ansible -i /etc/kolla/multinode bootstrap-servers
kolla-ansible -i /etc/kolla/multinode prechecks
kolla-ansible -i /etc/kolla/multinode deploy
kolla-ansible -i /etc/kolla/multinode post-deploy
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/$Openstack_Version
pip install python-magnumclient
pip install python-glanceclient
