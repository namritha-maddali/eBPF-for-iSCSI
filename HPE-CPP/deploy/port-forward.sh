#!/bin/bash

# Frontend (uml-service:80 → localhost:8080)
gnome-terminal -- bash -c "export KUBECONFIG=/etc/kubernetes/admin.conf; echo 'Forwarding uml-service:80 to localhost:8080'; kubectl port-forward svc/uml-service 8080:80 -n vmodel-lab; exec bash"

# Backend (uml-backend-service:3000 → localhost:3001)
gnome-terminal -- bash -c "export KUBECONFIG=/etc/kubernetes/admin.conf; echo 'Forwarding uml-backend-service:3000 to localhost:3001'; kubectl port-forward svc/uml-backend-service 3001:3000 -n vmodel-lab; exec bash"

# MySQL (uml-mysql-service:3306 → localhost:3306)
gnome-terminal -- bash -c "export KUBECONFIG=/etc/kubernetes/admin.conf; echo 'Forwarding uml-mysql-service:3306 to localhost:3306'; kubectl port-forward svc/uml-mysql-service 3306:3306 -n vmodel-lab; exec bash"

# Requirements Service (requirements-service:80 → localhost:8001)
#gnome-terminal -- bash -c "export KUBECONFIG=/etc/kubernetes/admin.conf; echo 'Forwarding requirements-service:80 to localhost:8001'; kubectl port-forward svc/requirements-service 8001:80 -n vmodel-lab; exec bash"

# Requirements MySQL (requirements-mysql-service:3306 → localhost:3307)
#gnome-terminal -- bash -c "export KUBECONFIG=/etc/kubernetes/admin.conf; echo 'Forwarding requirements-mysql-service:3306 to localhost:3307'; kubectl port-forward svc/requirements-mysql-service 3307:3306 -n vmodel-lab; exec bash"

gnome-terminal -- bash -c "export KUBECONFIG=/etc/kubernetes/admin.conf; echo 'Forwarding prometheus-kube-prometheus-prometheus to localhost:9090'; kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090; exec bash"

gnome-terminal -- bash -c "export KUBECONFIG=/etc/kubernetes/admin.conf; echo 'Forwarding prometheus-grafana:'; kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80; exec bash"

gnome-terminal -- bash -c "export KUBECONFIG=/etc/kubernetes/admin.conf; echo 'Forwarding Cilium Hubble UI:';kubectl -n kube-system port-forward svc/hubble-ui 12000:80; exec bash"

gnome-terminal -- bash -c "snap run firefox; exec bash"


