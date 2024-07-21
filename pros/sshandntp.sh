# SSH Key generation and copy ssh to other nodes 
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
sshpass -p gprm8350 ssh-copy-id -o StrictHostKeyChecking=no root@controller0
sshpass -p gprm8350 ssh-copy-id -o StrictHostKeyChecking=no root@controller1
sshpass -p gprm8350 ssh-copy-id -o StrictHostKeyChecking=no root@controller2
sshpass -p gprm8350 ssh-copy-id -o StrictHostKeyChecking=no root@compute0
sshpass -p gprm8350 ssh-copy-id -o StrictHostKeyChecking=no root@compute1
sshpass -p gprm8350 ssh-copy-id -o StrictHostKeyChecking=no root@compute2
sed 's/^pool/#&/' -i /etc/chrony.conf
echo -e "pool 0.us.pool.ntp.org  iburst \nallow 172.90.0.0/24 " >> /etc/chrony.conf
systemctl enable chronyd&&systemctl restart chronyd
scp -r /etc/chrony.conf root@controller0:/etc/chrony.conf
scp -r /etc/chrony.conf root@controller1:/etc/chrony.conf
scp -r /etc/chrony.conf root@controller2:/etc/chrony.conf
scp -r /etc/chrony.conf root@compute0:/etc/chrony.conf
scp -r /etc/chrony.conf root@compute1:/etc/chrony.conf
scp -r /etc/chrony.conf root@compute2:/etc/chrony.conf
ssh root@controller0 'systemctl enable chronyd && systemctl restart chronyd'
ssh root@controller1 'systemctl enable chronyd && systemctl restart chronyd'
ssh root@controller2 'systemctl enable chronyd && systemctl restart chronyd'
ssh root@compute0 'systemctl enable chronyd && systemctl restart chronyd'
ssh root@compute1 'systemctl enable chronyd && systemctl restart chronyd'
ssh root@compute2 'systemctl enable chronyd && systemctl restart chronyd'
