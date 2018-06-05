# -*- mode: ruby -*-
# vi: set ft=ruby :

# Autoinstall for vagrant-hostmanager plugin
unless Vagrant.has_plugin?('vagrant-hostmanager')
  # Attempt to install ourself.
  # Bail out on failure so we don't get stuck in an infinite loop.
  system('vagrant plugin install vagrant-hostmanager') || exit!

  # Relaunch Vagrant so the new plugin(s) are detected.
  # Exit with the same status code.
  exit system('vagrant', *ARGV)
end

Vagrant.configure("2") do |config|
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true

  config.vm.define "keitaro" do |app|
    app.ssh.insert_key = true
  
    app.vm.box = "centos/7"
    app.vm.hostname = "keitaro.dev"
    app.vm.network "private_network", ip: "192.168.100.10"
    app.vm.provider :virtualbox do |v|
      v.name = "keitaro"
      v.memory = 1024
      v.cpus = 1
    end

    app.vm.provision :ansible do |ansible|
      ansible.playbook = "playbook.yml"
      ansible.inventory_path = "hosts-vagrant"
      ansible.sudo = true
    end
  end
end
