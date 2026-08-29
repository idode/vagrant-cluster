install_munge:
  pkg.installed:
    - pkgs:
      - munge
      - libmunge2

# We dynamically pull the secure key from the Pillar. No hardcoding!
munge_key_file:
  file.managed:
    - name: /etc/munge/munge.key
    - contents_pillar: slurm:munge_key
    - user: munge
    - group: munge
    - mode: '0400'
    - require:
      - pkg: install_munge

start_munge:
  service.running:
    - name: munge
    - enable: True
    - watch:
      - file: munge_key_file