# We use a Salt Grain here to ensure this only attempts to run on Debian/Ubuntu systems
{% if grains['os_family'] == 'Debian' %}

{% if grains['id'] == 'controller' %}
install_slurm_deb:
  cmd.run:
    - name: apt-get install -y /shared/slurm-common_*_amd64.deb /shared/slurmctld_*_amd64.deb /shared/slurmdbd_*_amd64.deb /shared/slurm-client_*_amd64.deb
    - unless: dpkg -l | grep -q slurm-client

{% elif grains['id'] == 'compute' %}
install_slurm_deb:
  cmd.run:
    - name: apt-get install -y /shared/slurm-common_*_amd64.deb /shared/slurmd_*_amd64.deb
    - unless: dpkg -l | grep -q slurmd
{% endif %}

slurm_user:
  user.present:
    - name: slurm
    - system: True
    - shell: /usr/sbin/nologin

hosts_entry_controller:
  host.present:
    - ip: {{ pillar['cluster']['controller_ip'] }}
    - names:
      - controller

hosts_entry_compute:
  host.present:
    - ip: {{ pillar['cluster']['compute_ip'] }}
    - names:
      - compute

slurm_conf_file:
  file.managed:
    - name: /etc/slurm/slurm.conf
    - makedirs: True
    - source: salt://common/slurm.conf.jinja
    - template: jinja
    - require:
      - cmd: install_slurm_deb

slurmdbd_conf_file:
  file.managed:
    - name: /etc/slurm/slurmdbd.conf
    - makedirs: True
    - source: salt://common/slurmdbd.conf.jinja
    - template: jinja
    - mode: '600'
    - user: slurm
    - group: slurm
    - require:
      - cmd: install_slurm_deb
      - user: slurm_user

slurm_spool_dir:
  file.directory:
    - name: /var/spool/slurmctld
    - user: slurm
    - group: slurm
    - makedirs: True
    - require:
      - user: slurm_user

slurmd_spool_dir:
  file.directory:
    - name: /var/spool/slurmd
    - user: slurm
    - group: slurm
    - makedirs: True
    - require:
      - user: slurm_user

{% if grains['id'] == 'controller' %}
slurmdbd_service:
  service.running:
    - name: slurmdbd
    - enable: True
    - require:
      - file: slurmdbd_conf_file
      - user: slurm_user

# slurmctld registers with slurmdbd on startup and fails fatally on a
# fresh cluster if that connection is refused, so wait until slurmdbd
# is actually accepting connections on its port, not just "started"
# per systemd (which doesn't imply it's finished initializing).
wait_for_slurmdbd_ready:
  cmd.run:
    - name: |
        for i in $(seq 1 30); do
          ss -tln | grep -q ':6819 ' && exit 0
          sleep 2
        done
        exit 1
    - require:
      - service: slurmdbd_service

slurmctld_service:
  service.running:
    - name: slurmctld
    - enable: True
    - require:
      - file: slurm_conf_file
      - user: slurm_user
      - file: slurm_spool_dir
      - cmd: wait_for_slurmdbd_ready

{% elif grains['id'] == 'compute' %}
slurmd_service:
  service.running:
    - name: slurmd
    - enable: True
    - require:
      - file: slurm_conf_file
{% endif %}
{% endif %}