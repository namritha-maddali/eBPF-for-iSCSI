#!/bin/bash

# Usage: ./reset-and-join.sh "kubeadm join <your-join-command>"

JOIN_CMD="$1"

if [ -z "$JOIN_CMD" ]; then
  echo "[ERROR] No kubeadm join command provided."
  echo "Usage: $0 \"kubeadm join <args>\""
  exit 1
fi

echo "[INFO] Setting hostname to vm-clone"
sudo hostnamectl set-hostname vm-clone

echo "[INFO] Resetting kubeadm state"
sudo kubeadm reset -f

echo "[INFO] Removing Kubernetes PKI directory"
sudo rm -rf /etc/kubernetes/pki

echo "[INFO] Removing Kubernetes static pod manifests"
sudo rm -rf /etc/kubernetes/manifests

echo "[INFO] Clearing kubelet state"
sudo rm -rf /var/lib/kubelet/*

echo "[INFO] Removing CNI configuration"
sudo rm -rf /etc/cni

echo "[INFO] Deleting cni0 interface (if exists)"
sudo ip link delete cni0 2>/dev/null

echo "[INFO] Deleting flannel.1 interface (if exists)"
sudo ip link delete flannel.1 2>/dev/null

echo "[INFO] Disabling swap."
sudo swapoff -a

echo "[PATCH] Proper CNI config..."
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: true
EOF

echo "Restart containerd"
sudo systemctl restart containerd

echo "Check CNI is properly configured"
sudo crictl info | jq '.config.networkConfig'

echo "[INFO] Restarting kubelet service"
sudo systemctl restart kubelet

echo "[INFO] Worker will join cluster with:"
echo "$JOIN_CMD"

echo "[INFO] Executing kubeadm join..."
sudo $JOIN_CMD

