# -*- mode: ruby -*-
Vagrant.configure("2") do |config|
  config.vm.box = "generic/debian11"
  config.vm.hostname = "node"

  config.vm.synced_folder ".", "/vagrant"

  config.vm.provision "shell", inline: <<-SHELL
    echo "Running pre-provisioning tasks..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ntpdate
    apt-get dist-upgrade -y
    echo "Provisioned ! So, shutdown."
    echo "Do 'vagrant up' again."
    shutdown -h now
  SHELL

end
