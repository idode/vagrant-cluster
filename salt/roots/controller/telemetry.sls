# We dynamically inject the node's hostname into the container name using a Grain
run_node_exporter:
  cmd.run:
    - name: podman run -d --name node_exporter_{{ grains['id'] }} -p 9100:9100 quay.io/prometheus/node-exporter:latest
    - unless: podman ps -a --format {%raw%}"{{.Names}}"{%endraw%} | grep -q node_exporter
    - require:
      - pkg: install_podman # This references the state from common.podman