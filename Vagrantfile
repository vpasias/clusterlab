ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'

USERNAME = 'ubuntu'
#DEVICE = 'enp3s0'
BRIDGE1 = 'br1'
BRIDGE2 = 'br2'
#DISKSIZE = '30G'
#DISKPATH = '/media/STORAGE/VM'
IMAGE = 'generic/ubuntu2204'
MACADDR = 'RANDOM'
AUTOCONF = 'off'
SERVERIP = ''
DNS0IP = '172.16.1.1'
DNS1IP = ''
GATEWAYIP = '172.168.1.1'
NETMASK = '255.255.255.0'

nodes = {
  'n1.example.com' => [8, 32768, '172.16.1.101', 100],
  'n2.example.com' => [8, 32768, '172.16.1.102', 100],
  'n3.example.com' => [8, 32768, '172.16.1.103', 100],
#  'n4.example.com' => [8, 32768, '172.16.1.104', 100],
#  'n5.example.com' => [8, 32768, '172.16.1.105', 100],
#  'n6.example.com' => [8, 32768, '172.16.1.106', 100],
#  'n7.example.com' => [8, 32768, '172.16.1.107', 100],
}

Vagrant.configure("2") do |config|
  config.vm.box = "#{IMAGE}"
  config.vm.host_name = "#{USERNAME}"

  config.vm.provision 'file', source: '~/.ssh/id_rsa.pub', destination: '/tmp/id_rsa.pub'
  config.vm.provision 'file', source: './hosts', destination: '/tmp/hosts'

  config.vm.provision 'shell', privileged: true, inline: <<-SCRIPT
    sudo systemctl enable serial-getty@ttyS0.service
    sudo systemctl start serial-getty@ttyS0.service
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT==" net.ifnames=0 biosdevname=0"/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0 net.ifnames=0 biosdevname=0"/' /etc/default/grub
    sudo sed -i 's/#GRUB_TERMINAL=console/GRUB_TERMINAL="serial console"/' /etc/default/grub
    sudo update-grub
    sudo swapoff -a
    sudo sed -i '/swap/d' /etc/fstab
    sudo echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu
    sudo chmod 440 /etc/sudoers.d/ubuntu
    sudo apt-get update
    useradd -m #{USERNAME} --groups sudo
    su -c "printf 'cd /home/#{USERNAME}\nsudo su #{USERNAME}' >> .bash_profile" -s /bin/sh vagrant
    sudo -u #{USERNAME} mkdir -p /home/#{USERNAME}/.ssh
    sudo -u #{USERNAME} cat /tmp/id_rsa.pub >> /home/#{USERNAME}/.ssh/authorized_keys
    sudo chsh -s /bin/bash #{USERNAME}
    sudo cp /tmp/hosts /etc/hosts
  SCRIPT
  
  nodes.each do | (name, cfg) |
    cpus, memory, ip, dsize = cfg
    
    config.vm.define name do |node|
      node.vm.hostname = name
      node.ssh.insert_key = false
      
      node.vm.network :public_network,
        :dev => BRIDGE1,
        :mode => 'bridge',
        :type => 'bridge',
        :ip => ip,
        :netmask => NETMASK,
        :dns => DNS0IP,
        :gateway => GATEWAYIP,
        :keep => true

      node.vm.network :public_network,
        :dev => BRIDGE2,
        :mode => 'bridge',
        :type => 'bridge',
        :keep => true

      node.vm.provider :libvirt do |libvirt|
        libvirt.management_network_keep = true
        libvirt.driver = 'kvm'
        libvirt.default_prefix = ''
        libvirt.host = ''
        libvirt.cpu_mode = 'host-passthrough'
        libvirt.nested = true
        libvirt.graphics_type = 'none'
        libvirt.video_type = 'none'
        libvirt.nic_model_type = 'virtio'
        libvirt.cpus = cpus
        libvirt.memory = memory
        libvirt.disk_device = 'sda'
        libvirt.disk_bus = 'sata'
        libvirt.disk_driver :cache => 'writeback'
        libvirt.autostart = true
        libvirt.storage :file, bus: 'sata', device: 'sdb', size: dsize
      end
    end
  end
end
