# frozen_string_literal: true

# -*- mode: ruby -*-
# vi: set ft=ruby :
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2020
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

require "yaml"

def which(cmd)
  exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
  ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

nodes = YAML.load_file("#{File.dirname(__FILE__)}/pdf.yml")
vagrant_boxes = YAML.load_file("#{File.dirname(__FILE__)}/distros_supported.yml")

no_proxy = ENV["NO_PROXY"] || ENV["no_proxy"] || "127.0.0.1,localhost"
hosts = "127.0.0.1   localhost\n"
hosts += `virsh net-dhcp-leases administration | grep 10.0.2 | grep -v undercloud | awk '{ sub("/24", "", $5); print($5,$6)}'` if which "virsh"
nodes.each do |node|
  next unless node.key? "networks"

  node["networks"].each do |network|
    no_proxy += ",#{network['ip']}"
    hosts += "#{network['ip']} #{node['name']}\n"
  end
end
(1..254).each do |i|
  no_proxy += ",10.0.2.#{i}"
end
# NOTE: This is the kolla_internal_vip_address value
no_proxy += ",172.16.1.3"
socks_proxy = ENV["socks_proxy"] || ENV["SOCKS_PROXY"] || ""

os_distro = ENV["OS_DISTRO"] || "ubuntu_22"
box = vagrant_boxes[os_distro]

system("echo -e \"\n\n\n\" | ssh-keygen -f #{File.dirname(__FILE__)}/insecure_keys/key -t rsa -N ''") unless File.exist?("#{File.dirname(__FILE__)}/insecure_keys/key")

Vagrant.configure("2") do |config|
  config.vm.provider :libvirt
  config.vm.provider :virtualbox

  config.vm.synced_folder "/", "/vagrant"
  config.vm.box = box["name"]
  config.vm.box_version = box["version"]
  config.ssh.insert_key = false
  config.vm.provider :libvirt do |v, override|
    override.vm.synced_folder "/", "/vagrant", type: "virtiofs"
    v.memorybacking :access, mode: "shared"
    v.management_network_address = "10.0.2.0/24"
    v.management_network_name = "administration" # Administration - Provides Internet access for all nodes and is used for administration to install software packages
    v.random_hostname = true
    v.cpu_mode = "host-passthrough"
    v.disk_device = "sda"
    v.disk_bus = "sata"
  end
  config.vm.provider "virtualbox" do |v|
    v.gui = false
    v.customize ["modifyvm", :id, "--nictype1", "virtio", "--cableconnected1", "on"]
    # Enable nested paging for memory management in hardware
    v.customize ["modifyvm", :id, "--nestedpaging", "on"]
    # Use large pages to reduce Translation Lookaside Buffers usage
    v.customize ["modifyvm", :id, "--largepages", "on"]
    # Use virtual processor identifiers  to accelerate context switching
    v.customize ["modifyvm", :id, "--vtxvpid", "on"]
  end

  if Vagrant.has_plugin?("vagrant-proxyconf") && (!ENV["http_proxy"].nil? || !ENV["HTTP_PROXY"].nil? || !ENV["https_proxy"].nil? || !ENV["HTTPS_PROXY"].nil?)
    config.proxy.http = ENV["http_proxy"] || ENV["HTTP_PROXY"] || ""
    config.proxy.https    = ENV["https_proxy"] || ENV["HTTPS_PROXY"] || ""
    config.proxy.no_proxy = no_proxy
    config.proxy.enabled = { docker: false }
  end

  # Basic requirements installation
  config.vm.provision "shell", path: "#{File.dirname(__FILE__)}/base.sh"

  config.vm.provision "shell", inline: <<~SHELL
    if command -v sestatus; then
        sudo setenforce Permissive
        sudo sed -i "s/^SELINUX=.*/SELINUX=permissive/g" /etc/selinux/config
    fi
  SHELL
  config.trigger.after :up do |trigger|
    trigger.info = "Configure Authorized Keys"
    trigger.run_remote = { inline: "cat /vagrant/insecure_keys/key.pub >> /home/vagrant/.ssh/authorized_keys" }
  end

  nodes.each do |node|
    config.vm.define node["name"] do |nodeconfig|
      nodeconfig.vm.hostname = node["name"]

      %i[virtualbox libvirt].each do |provider|
        nodeconfig.vm.provider provider do |p|
          p.cpus = node["cpus"]
          p.memory = node["memory"]
        end
      end

      # Networks
      if node.key? "networks"
        node["networks"].each do |network|
          nodeconfig.vm.network :private_network, ip: network["ip"], type: :static, libvirt__network_name: network["name"], nic_type: "virtio", virtualbox__intnet: true
        end
      end
      nodeconfig.vm.network :private_network, ip: "0.0.0.0", auto_network: true, libvirt__network_name: "external-net", nic_type: "virtio", virtualbox__intnet: true if node["roles"].include?("network")

      nodeconfig.vm.provider "virtualbox" do |v|
        if node.key? "volumes"
          node["volumes"].each do |volume|
            volume_file = "#{node['name']}-#{volume['name']}.vdi"
            v.customize ["createmedium", "disk", "--filename", volume_file, "--size", (volume["size"] * 1024)] unless File.exist?(volume_file)
            v.customize ["storageattach", :id, "--storagectl", box["vb_controller"], "--port", 1, "--device", 0, "--type", "hdd", "--medium", volume_file]
          end
        end
      end
      nodeconfig.vm.provider :libvirt do |v|
        v.nested = true
      end
    end
  end
