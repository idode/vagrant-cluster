#!/bin/bash
# scripts/build_slurm.sh
set -e

echo "=== Starting Slurm Compilation on Builder Node ==="

# 1. Install build dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y build-essential wget munge libmunge-dev libmariadb-dev \
                   ruby ruby-dev python3 dbus \
                   libbpf-dev libdbus-1-dev \
                   podman
gem install fpm

# 2. Download Slurm Source
SLURM_VERSION="23.11.4"
cd /tmp
wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2
tar -xjf slurm-${SLURM_VERSION}.tar.bz2
cd slurm-${SLURM_VERSION}

# 3. Configure and Compile
echo "=== Configuring and Compiling Slurm ==="
./configure --prefix=/usr --sysconfdir=/etc/slurm --with-munge \
    --with-systemdsystemunitdir=/usr/lib/systemd/system
make -j$(nproc)

# 4. Package into a DEB file
echo "=== Packaging DEB with FPM ==="
mkdir -p /tmp/slurm-build
make install DESTDIR=/tmp/slurm-build

fpm -f -s dir -t deb \
    -n slurm-common \
    -v ${SLURM_VERSION} \
    -C /tmp/slurm-build \
    -p /shared/slurm-common_${SLURM_VERSION}_amd64.deb \
    usr/lib/libslurm.so.40.0.0 usr/lib/libslurm.so usr/lib/slurm

fpm -f -s dir -t deb \
    -n slurmctld \
    -v ${SLURM_VERSION} \
    -d "slurm-common" \
    -C /tmp/slurm-build \
    -p /shared/slurmctld_${SLURM_VERSION}_amd64.deb \
    usr/sbin/slurmctld usr/lib/systemd/system/slurmctld.service

fpm -f -s dir -t deb \
    -n slurmd \
    -v ${SLURM_VERSION} \
    -d "slurm-common" \
    -C /tmp/slurm-build \
    -p /shared/slurmd_${SLURM_VERSION}_amd64.deb \
    usr/sbin/slurmd usr/sbin/slurmstepd usr/lib/systemd/system/slurmd.service

fpm -f -s dir -t deb \
    -n slurm-client \
    -v ${SLURM_VERSION} \
    -d "slurm-common" \
    -C /tmp/slurm-build \
    -p /shared/slurm-client_${SLURM_VERSION}_amd64.deb \
    usr/bin/sinfo usr/bin/squeue usr/bin/sbatch usr/bin/srun \
    usr/bin/scancel usr/bin/scontrol usr/bin/sacct usr/bin/sacctmgr

fpm -f -s dir -t deb \
    -n slurmdbd \
    -v ${SLURM_VERSION} \
    -d "slurm-common" \
    -C /tmp/slurm-build \
    -p /shared/slurmdbd_${SLURM_VERSION}_amd64.deb \
    usr/sbin/slurmdbd usr/lib/systemd/system/slurmdbd.service

podman build --build-arg SLURM_VERSION=${SLURM_VERSION} -t slurm-client:${SLURM_VERSION} -f /vagrant/scripts/Containerfile /shared
# podman save (docker-archive format) refuses to overwrite an existing file,
# so remove any artifact left over from a previous build first.
rm -f /shared/slurm-client_${SLURM_VERSION}.tar
podman save -o /shared/slurm-client_${SLURM_VERSION}.tar slurm-client:${SLURM_VERSION}

podman build -t metrics-gateway:latest -f /vagrant/metrics-gateway/Containerfile /vagrant/metrics-gateway
rm -f /shared/metrics-gateway.tar
podman save -o /shared/metrics-gateway.tar metrics-gateway:latest


echo "=== Build Complete! Artifact generated in /shared ==="

# 5. Ephemeral shutdown
echo "Shutting down the builder node as requested..."
shutdown -h now
