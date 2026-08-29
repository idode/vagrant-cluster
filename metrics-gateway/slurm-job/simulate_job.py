#!/usr/bin/env python3
#SBATCH --job-name=metrics-sim
#SBATCH --partition=debug
#SBATCH --time=00:02:00
#SBATCH --output=/tmp/slurm-metrics-job-%j.out
import os
import json
import time
import random
import urllib.request

# GATEWAY_URL is normally injected by the sbatch env (see
# salt/roots/controller/metrics_cron.sls, sourced from Pillar). The
# fallback below only matters for a manual/standalone run of this script.
GATEWAY_HOST = os.environ.get("GATEWAY_URL", "10.10.10.12:30080")
GATEWAY_URL = f"http://{GATEWAY_HOST}/update-metric"

def generate_realistic_walk(steps=12, start_val=50, step_size=7):
    data = [start_val]
    for _ in range(steps - 1):
        movement = random.uniform(-step_size, step_size)
        next_val = data[-1] + movement
        next_val = max(0, min(100, next_val))
        data.append(round(next_val, 2))
    return data

def send_metric(name, value, job_id, node_name):
    payload = {
        "metric_name": name,
        "value": value,
        "labels": {"slurm_job_id": job_id, "slurmd_nodename": node_name}
    }
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        GATEWAY_URL, data=data,
        headers={"Content-Type": "application/json"},
        method="PUT"
    )
    urllib.request.urlopen(req)

job_id = os.environ.get("SLURM_JOB_ID", "unknown")
node_name = os.environ.get("SLURMD_NODENAME", "unknown")

cpu_walk = generate_realistic_walk()
gpu_walk = generate_realistic_walk()
mem_walk = generate_realistic_walk()

for i in range(12):
    send_metric("slurm_job_cpu_load", cpu_walk[i], job_id, node_name)
    send_metric("slurm_job_gpu_load", gpu_walk[i], job_id, node_name)
    send_metric("slurm_job_mem_load", mem_walk[i], job_id, node_name)
    print(f"[{i+1}/12] cpu={cpu_walk[i]} gpu={gpu_walk[i]} mem={mem_walk[i]}")
    time.sleep(5)