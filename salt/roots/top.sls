base:
  # Applied to all Slurm nodes
  'controller or compute':
    - match: compound
    - common.munge

  # slurmdbd needs the accounting DB to exist before it starts, so
  # mariadb must run before common.slurm_core on the controller.
  'controller':
    - controller.mariadb
    - common.slurm_core
    - controller.telemetry
    - common.podman
    - controller.metrics_cron

  'compute':
    - common.slurm_core
    - compute.k3s
