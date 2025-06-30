#!/bin/bash

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[INFO] Launching port-forwards in tmux sessions..."

# Frontend
tmux new-session -d -s uml-frontend "echo 'Forwarding uml-service:80 to localhost:8888'; kubectl port-forward svc/uml-service 8888:80 -n vmodel-lab"

# Backend
tmux new-session -d -s uml-backend "echo 'Forwarding uml-backend-service:3000 to localhost:3001'; kubectl port-forward svc/uml-backend-service 3001:3000 -n vmodel-lab"

# MySQL
tmux new-session -d -s uml-mysql "echo 'Forwarding uml-mysql-service:3306 to localhost:3306'; kubectl port-forward svc/uml-mysql-service 3306:3306 -n vmodel-lab"

# Requirements Service (commented)
# tmux new-session -d -s req-service "echo 'Forwarding requirements-service:80 to localhost:8001'; kubectl port-forward svc/requirements-service 8001:80 -n vmodel-lab"

# Requirements MySQL (commented)
# tmux new-session -d -s req-mysql "echo 'Forwarding requirements-mysql-service:3306 to localhost:3307'; kubectl port-forward svc/requirements-mysql-service 3307:3306 -n vmodel-lab"

# Prometheus
tmux new-session -d -s prometheus "echo 'Forwarding prometheus-kube-prometheus-prometheus to localhost:9090'; kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090 -n monitoring"

# Grafana
tmux new-session -d -s grafana "echo 'Forwarding prometheus-grafana to localhost:3000'; kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"

# Hubble UI
tmux new-session -d -s hubble "echo 'Forwarding Cilium Hubble UI to localhost:12000'; kubectl -n kube-system port-forward svc/hubble-ui 12000:80"

# Optional: Firefox launch (can’t use tmux meaningfully here)
snap run firefox &

echo "[INFO] All tmux sessions started. Use 'tmux ls' to view and 'tmux attach -t <name>' to interact."

