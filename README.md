# vagrant-cluster

A self-contained, 3-VM HPC lab built with Vagrant + VirtualBox + SaltStack: a Slurm
cluster (controller + compute) with accounting, plus a lightweight k3s-based
observability stack (Prometheus/Grafana + node-exporter) fed by a custom metrics
gateway that Slurm jobs report into.

## Architecture

| VM | Role | IP | Notes |
|---|---|---|---|
| `builder` | Compiles Slurm 23.11.4 from source, packages it as `.deb`s, builds the container images | `10.10.10.10` | Runs once, writes artifacts to `shared/`, then shuts itself down |
| `controller` | Salt master + minion, `slurmctld`/`slurmdbd`, MariaDB (accounting DB), node-exporter | `10.10.10.11` | Also submits a synthetic metrics job via cron every 5 minutes |
| `compute` | Salt minion, `slurmd`, node-exporter, k3s running kube-prometheus-stack + ingress-nginx + `metrics-gateway` | `10.10.10.12` | Runs the actual Slurm jobs and hosts the observability stack |

Config management is SaltStack, laid out as:
- `salt/roots/common/` — states applied to both `controller` and `compute` (munge, Slurm packages/config, podman)
- `salt/roots/controller/` — controller-only states (MariaDB, node-exporter, the metrics cron job)
- `salt/roots/compute/` — compute-only states (k3s, Helm, Prometheus/Grafana values, the metrics-gateway deploy)
- `salt/pillar/` — secrets (munge key, DB password) injected via Pillar, never hardcoded into states

`metrics-gateway/` is a small Flask app (`PUT /update-metric`, `GET /metrics`) that Slurm
jobs push synthetic CPU/GPU/mem load into, exposed to Prometheus in text exposition format.

## Prerequisites

- [Vagrant](https://www.vagrantup.com/) (2.2+, for the `trigger` support used in the Vagrantfile)
- [VirtualBox](https://www.virtualbox.org/)
- ~8 GB RAM and a few GB of free disk available to VMs (`builder` uses 2 GB, `controller`/`compute` 3 GB each)

## Running it

```sh
vagrant up
```

This provisions VMs in the order they're defined in the `Vagrantfile`:

1. **`builder`** compiles Slurm and builds the `slurm-client` and `metrics-gateway` container
   images, writing everything to `shared/` (synced to `/shared` on every VM). It shuts itself
   down when done — this must complete before `controller`/`compute` provisioning, since
   both install Slurm from the `.deb`s it produces.
2. **`controller`** installs the Salt master + its own minion, waits for its minion key to
   register, accepts it, then runs `state.highstate` (installs `slurmctld`/`slurmdbd`, MariaDB,
   node-exporter, the metrics cron job).
3. **`compute`** installs its Salt minion, then a Vagrant trigger SSHes into `controller` to
   accept compute's minion key and runs `state.highstate` there (installs `slurmd`, k3s, and
   the Helm-deployed Prometheus/Grafana/metrics-gateway stack).

> The Salt master does **not** auto-accept minion keys (`auto_accept: False` in
> `salt/master`) — key acceptance is scripted explicitly in the `Vagrantfile` instead, so
> `vagrant up` still works end-to-end without a manual `salt-key -A`, but the acceptance step
> stays visible and auditable in the repo rather than being an invisible default.

Because k3s and the Helm charts can take a few minutes to become ready, `vagrant up` for
`compute` may take 5-10 minutes on first run.

To re-provision without rebuilding VMs:

```sh
vagrant provision controller
vagrant provision compute   # also re-runs the key-acceptance trigger
```

## Accessing Grafana

The compute node runs ingress-nginx, and Grafana is exposed at the hostname `grafana.local`.
Point your host machine at the compute node's IP:

- **Windows**: add a line to `C:\Windows\System32\drivers\etc\hosts` (as Administrator):
  ```
  10.10.10.12 grafana.local
  ```
- **macOS/Linux**: add the same line to `/etc/hosts`.

Then browse to **http://grafana.local/**.

- Username: `admin`
- Password: `admin_password` in `salt/pillar/grafana_secrets.sls`

The pre-loaded **node-exporter-full** dashboard shows host-level CPU/mem/disk/network for both
`controller` and `compute`. The synthetic Slurm job metrics (`slurm_job_cpu_load`,
`slurm_job_gpu_load`, `slurm_job_mem_load`) are scraped from `metrics-gateway` and can be
graphed via Grafana's Explore view against the `Prometheus` datasource.

You can also hit the metrics gateway directly, bypassing Grafana:
```sh
curl http://10.10.10.12:30080/metrics
```

## Repository layout

```
Vagrantfile
scripts/
  build_slurm.sh          # compiles Slurm, packages .debs, builds container images
  Containerfile            # container image for a Slurm client
salt/
  master, minion_controller, minion_compute
  pillar/                  # secrets (Slurm, Grafana) + cluster topology (node IPs) — see note below
  roots/
    common/                # states shared by controller + compute
    controller/             # controller-only states
    compute/                 # compute-only states
metrics-gateway/
  app.py                   # Flask metrics receiver/exporter
  helm-chart/               # deploys metrics-gateway into k3s
  slurm-job/                # the synthetic job Slurm jobs run to feed metrics
shared/                    # build artifacts (.deb/.tar) — gitignored, produced by builder
```

## Secrets

`salt/pillar/slurm_secrets.sls` (munge key, Slurm accounting DB password) and
`salt/pillar/grafana_secrets.sls` (Grafana admin password) hold real random values as
plaintext, generated with `dd if=/dev/urandom bs=1 count=1024 | base64` / `openssl rand
-base64 24`. These are committed to the repo — acceptable for an isolated local lab with no
real data, **not** a pattern to carry into anything real (that would call for something like
`sops`/`git-crypt` so the pillar files are safe to commit encrypted).

## Known gaps / follow-ups

These are known, not accidental — flagged here rather than fixed silently:

- `metrics-gateway`'s `PUT /update-metric` has no authentication and does minimal input validation.
- Container image tags (`node-exporter:latest`, `metrics-gateway:latest`) aren't pinned, and `requirements.txt` doesn't pin a Flask version — rebuilds aren't guaranteed reproducible.
- The Python interpreter path in `salt/roots/controller/mariadb.sls` (`/opt/saltstack/salt/bin/python3.14`) is hardcoded to one Salt onedir bundle's Python version rather than derived dynamically.

