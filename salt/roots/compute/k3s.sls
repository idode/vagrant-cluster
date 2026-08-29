{% if grains['id'] == 'compute' %}
install_k3s:
  cmd.run:
    - name: curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
    - unless: which k3s
    - require:
      - cmd: install_slurm_deb

wait_for_k3s_ready:
  cmd.run:
    - name: |
        for i in $(seq 1 30); do
          k3s kubectl get nodes 2>/dev/null | grep -q " Ready" && exit 0
          sleep 5
        done
        exit 1
    - require:
      - cmd: install_k3s

install_helm:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    - unless: which helm
    - require:
      - cmd: wait_for_k3s_ready

helm_repo_prometheus:
  cmd.run:
    - name: helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update
    - unless: helm repo list | grep -q prometheus-community
    - env:
      - KUBECONFIG: /etc/rancher/k3s/k3s.yaml
    - require:
      - cmd: install_helm

helm_repo_ingress_nginx:
  cmd.run:
    - name: helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
    - unless: helm repo list | grep -q ingress-nginx
    - env:
      - KUBECONFIG: /etc/rancher/k3s/k3s.yaml
    - require:
      - cmd: install_helm

prometheus_and_grafana_values:
  file.managed:
    - name: /tmp/prometheus-values.yaml
    - source: salt://compute/prometheus-values.yaml
    - template: jinja
    - require:
      - cmd: helm_repo_prometheus
      - cmd: helm_repo_ingress_nginx

run_prometheus_and_grafana:
  cmd.run:
    - name: helm install prometheus prometheus-community/kube-prometheus-stack -f /tmp/prometheus-values.yaml
    - unless: helm list -n default | grep -q prometheus
    - env:
      - KUBECONFIG: /etc/rancher/k3s/k3s.yaml
    - require:
      - file: prometheus_and_grafana_values

install_ingress_nginx:
  cmd.run:
    - name: helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
    - unless: helm list -n ingress-nginx | grep -q ingress-nginx
    - env:
      - KUBECONFIG: /etc/rancher/k3s/k3s.yaml
    - require:
      - cmd: helm_repo_ingress_nginx
ingress_nginx_values:
  file.managed:
    - name: /tmp/grafana-ingress.yaml
    - source: salt://compute/grafana-ingress.yaml
    - require:
      - cmd: helm_repo_ingress_nginx

run_grafana_ingress:
  cmd.run:
    - name: k3s kubectl apply -f /tmp/grafana-ingress.yaml
    - unless: k3s kubectl get ingress grafana-ingress
    - require:
      - file: ingress_nginx_values
      - cmd: wait_for_ingress_nginx_ready

wait_for_ingress_nginx_ready:
  cmd.run:
    - name: |
        for i in $(seq 1 30); do
          k3s kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q true && exit 0
          sleep 5
        done
        exit 1
    - require:
      - cmd: install_ingress_nginx

ctr_import_metrics_gateway:
  cmd.run:
    - name: k3s ctr images import /shared/metrics-gateway.tar
    - unless: k3s ctr images list | grep -q metrics-gateway
    - require:
      - cmd: wait_for_k3s_ready

deploy_metrics_gateway:
  cmd.run:
    - name: helm install metrics-gateway /vagrant/metrics-gateway/helm-chart
    - unless: helm list | grep -q metrics-gateway
    - env:
      - KUBECONFIG: /etc/rancher/k3s/k3s.yaml
    - require:
      - cmd: ctr_import_metrics_gateway
      - cmd: install_helm

{% endif %}