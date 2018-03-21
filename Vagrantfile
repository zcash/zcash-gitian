# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|

  config.ssh.forward_agent = true
  config.disksize.size = '16GB'
  config.vm.define 'zcash-build', autostart: false do |gitian|
    gitian.vm.box = "debian/jessie64"
    gitian.vm.network "forwarded_port", guest: 22, host: 2200, auto_correct: true
    gitian.vm.provision "ansible" do |ansible|
      ansible.playbook = "gitian.yml"
      ansible.verbose = 'v'
      ansible.raw_arguments = Shellwords.shellsplit(ENV['ANSIBLE_ARGS']) if ENV['ANSIBLE_ARGS']
    end
    gitian.vm.provider "virtualbox" do |v|
      v.name = "zcash-build"
      v.memory = 4096
      v.cpus = 2
    end
#    gitian.vm.synced_folder "~/.gnupg", "/home/vagrant/.gnupg", type: "sshfs"
#    gitian.vm.synced_folder "./gitian.sigs", "/home/vagrant/gitian.sigs", create: true
#    gitian.vm.synced_folder "./zcash-binaries", "/home/vagrant/zcash-binaries", create: true
    gitian.vm.post_up_message = "Zcash deterministic build environment started."
  end

end
