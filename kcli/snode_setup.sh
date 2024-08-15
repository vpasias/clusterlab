#! /bin/sh

DEBIAN_FRONTEND=noninteractive apt update
DEBIAN_FRONTEND=noninteractive apt -y install nfs-kernel-server 
DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-simplejson xfsprogs sshpass
DEBIAN_FRONTEND=noninteractive apt install -y corosync glusterfs-server nfs-ganesha-gluster pacemaker pcs

modprobe -v xfs
grep xfs /proc/filesystems
modinfo xfs

mkdir -p /etc/apt/sources.list.d

systemctl enable --now nfs-server
#systemctl restart nfs-server

mkfs.xfs -f -i size=512 -L gluster-000 /dev/vdc

mkdir -p /data/glusterfs/sharedvol/mybrick
echo 'LABEL=gluster-000 /data/glusterfs/sharedvol/mybrick xfs defaults  0 0' >> /etc/fstab
mount /data/glusterfs/sharedvol/mybrick

systemctl enable --now glusterd

mv /etc/ganesha/ganesha.conf /etc/ganesha/old.ganesha.conf

cat << EOF | tee /etc/ganesha/ganesha.conf
EXPORT{
    Export_Id = 1 ;       # Unique identifier for each EXPORT (share)
    Path = "/sharedvol";  # Export path of our NFS share

    FSAL {
        name = GLUSTER;          # Backing type is Gluster
        hostname = "localhost";  # Hostname of Gluster server
        volume = "sharedvol";    # The name of our Gluster volume
    }

    Access_type = RW;          # Export access permissions
    Squash = No_root_squash;   # Control NFS root squashing
    Disable_ACL = FALSE;       # Enable NFSv4 ACLs
    Pseudo = "/sharedvol";     # NFSv4 pseudo path for our NFS share
    Protocols = "3","4" ;      # NFS protocols supported
    Transports = "UDP","TCP" ; # Transport protocols supported
    SecType = "sys";           # NFS Security flavors supported
}
EOF

apt update -y

reboot
