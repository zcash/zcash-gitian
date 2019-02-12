# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|

  config.ssh.forward_agent = true
  config.vm.define 'zcash-build', autostart: false do |gitian|
    gitian.vm.box = "debian/jessie64"
    gitian.vm.network :private_network, :ip => "10.0.2.15" 
    gitian.vm.provision "ansible" do |ansible|
      ansible.playbook = "gitian.yml"
      ansible.verbose = 'v'
      ansible.raw_arguments = Shellwords.shellsplit(ENV['ANSIBLE_ARGS']) if ENV['ANSIBLE_ARGS']
    end
    gitian.vm.provider :libvirt do |domain|
      domain.machine_virtual_size = 24
      domain.memory = 15360 
      domain.cpus = 4
    end
    gitian.vm.hostname = "zcash-build"
#    gitian.vm.synced_folder "~/.gnupg", "/home/vagrant/.gnupg", type: "sshfs"
#    gitian.vm.synced_folder "./gitian.sigs", "/home/vagrant/gitian.sigs", create: true
#    gitian.vm.synced_folder "./zcash-binaries", "/home/vagrant/zcash-binaries", create: true
    gitian.vm.post_up_message = "Zcash deterministic build environment started."
  end

end
