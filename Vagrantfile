# -*- mode: ruby -*-
# vi: set ft=ruby :
# Node IPs below (10.10.10.11 controller / 10.10.10.12 compute) must stay
# in sync with salt/pillar/cluster_topology.sls, which is the source Salt
# states/templates use instead of hardcoding these addresses themselves.
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.synced_folder "./shared", "/shared"
  
  config.vm.define "builder" do |builder|
    builder.vm.hostname = "builder"
    builder.vm.network "private_network", ip: "10.10.10.10"
    builder.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
    end
    builder.vm.provision "shell", path: "scripts/build_slurm.sh"
  end


  config.vm.define "controller" do |controller|
    controller.vm.synced_folder "./salt/pillar", "/srv/pillar"
    controller.vm.synced_folder "./salt/roots", "/srv/salt" 
    controller.vm.hostname = "controller"
    controller.vm.network "private_network", ip: "10.10.10.11"
    controller.vm.provider "virtualbox" do |vb|
      vb.memory = "3072"
      vb.cpus = 2
    end
    controller.vm.provision :salt do |salt|
      salt.master_config = "salt/master"
      salt.minion_config = "salt/minion_controller"
      salt.install_master = true
      salt.install_type = "stable"
    end
    # auto_accept is off (salt/master), so accept the controller's own
    # minion key once it shows up before running highstate against it.
    controller.vm.provision "shell", inline: <<-SHELL
      for i in $(seq 1 30); do
        salt-key -l unaccepted 2>/dev/null | grep -q '^controller$' && break
        sleep 2
      done
      salt-key -A -y
      salt-call state.highstate
    SHELL
  end

  config.vm.define "compute" do |compute|
    compute.vm.hostname = "compute"
    compute.vm.network "private_network", ip: "10.10.10.12"
    compute.vm.provider "virtualbox" do |vb|
      vb.memory = "3072"
      vb.cpus = 2
    end
    compute.vm.provision :salt do |salt|
      salt.minion_config = "salt/minion_compute"
      salt.install_type = "stable"
    end
  end

  # compute's minion key can only be accepted from the master (controller),
  # so it's a separate host-driven step rather than salt.run_highstate:
  # accept the key on controller, then trigger compute's highstate.
  config.trigger.after [:up, :provision] do |trigger|
    trigger.name = "Accept compute's minion key and run its highstate"
    trigger.only_on = "compute"
    trigger.ruby do |env, machine|
      system("vagrant", "ssh", "controller", "-c", "sudo salt-key -A -y")
      system("vagrant", "ssh", "compute", "-c", "sudo salt-call state.highstate")
    end
  end
end