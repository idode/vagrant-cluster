# Single source of truth for node IPs used across Salt states/templates.
# Must stay in sync with the private_network IPs in the Vagrantfile —
# Vagrant/VirtualBox network config and Salt pillar data are separate
# layers, so this can't be derived automatically from the Vagrantfile.
cluster:
  controller_ip: 10.10.10.11
  compute_ip: 10.10.10.12
