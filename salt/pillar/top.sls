base:
  'controller or compute':
    - match: compound
    - slurm_secrets
    - cluster_topology

  'compute':
    - grafana_secrets
