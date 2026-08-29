metrics_job_cron:
  cron.present:
    - name: GATEWAY_URL={{ pillar['cluster']['compute_ip'] }}:30080 /usr/bin/sbatch /vagrant/metrics-gateway/slurm-job/simulate_job.py
    - user: vagrant
    - minute: '*/5'
    - hour: '*'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'