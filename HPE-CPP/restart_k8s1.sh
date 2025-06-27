#!/bin/bash

echo "[INFO] Setting PS1 prompt."
export PS1="Rashmi$\w\n"

#echo "deleting pixie currently"
#px delete

echo "[INFO] Resetting Kubernetes cluster."
sudo kubeadm reset -f

echo "[INFO] Removing CNI network configurations."
sudo rm -rf /etc/cni/net.d

echo "[INFO] Deleting cni0 network link."
sudo ip link delete cni0

echo "[INFO] Deleting flannel.1 network link."
sudo ip link delete flannel.1

echo "[INFO] Stopping kubelet service."
sudo systemctl stop kubelet

echo "[INFO] Stopping containerd service (if using containerd)."
sudo systemctl stop containerd  # If using containerd

echo "[INFO] Stopping Docker service (if using Docker)."
sudo systemctl stop docker      # If using Docker

echo "[INFO] Killing kubelet process."
sudo pkill -9 kubelet

echo "[INFO] Killing etcd process."
sudo pkill -9 etcd

echo "[INFO] Killing kube-apiserver process."
sudo pkill -9 kube-apiserver

echo "[INFO] Killing kube-controller process."
sudo pkill -9 kube-controller

echo "[INFO] Killing kube-scheduler process."
sudo pkill -9 kube-scheduler

echo "[INFO] Removing Kubernetes, etcd, and kubelet directories."
sudo rm -rf /etc/kubernetes/ /var/lib/etcd /var/lib/kubelet

echo "[INFO] Disabling swap."
sudo swapoff -a

echo "[INFO] Restarting Docker service."
sudo systemctl restart docker

echo "[INFO] Restarting containerd service (or restart Docker if using Docker)."
sudo systemctl restart containerd

echo "[INFO] Restarting kubelet service."
sudo systemctl restart kubelet

echo "[INFO] Initializing Kubernetes cluster with Flannel network."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

echo "[INFO] Creating .kube directory."
mkdir -p $HOME/.kube

echo "[INFO] Copying Kubernetes admin.conf to .kube/config (without overwriting)."
sudo cp -n /etc/kubernetes/admin.conf $HOME/.kube/config

echo "[INFO] Changing ownership of .kube/config."
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[INFO] Setting permissions for /etc/kubernetes/admin.conf."
sudo chmod 644 /etc/kubernetes/admin.conf

echo "[INFO] Changing ownership of /etc/kubernetes/admin.conf."
sudo chown $(id -u):$(id -g) /etc/kubernetes/admin.conf

echo "[INFO] Setting KUBECONFIG environment variable."
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[INFO] Retrieving Kubernetes cluster information."
kubectl cluster-info

echo "[INFO] Applying Flannel CNI network."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo "[INFO] Removing taints from control plane nodes."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "[INFO] Checking if persistent volumes are available."
kubectl get storageclass

echo "[INFO] Checking if pem nodes have PRIVILEGED ACCESS."
kubectl edit daemonset vizier-pem -n pl | grep privileged

echo "[INFO] Updating PATH environment variable."
export PATH=$PATH:/home/seed/bin

echo "[INFO] Checking if internet access is working."
export PX_CLOUD_ADDR=getcosmic.ai

echo "[INFO] Logging into Pixie."
px auth login --manual

echo "[INFO] Installing the Pixie CLI. Copy and run the command that appears."
bash -c "$(curl -fsSL https://getcosmic.ai/install.sh)"

echo "[INFO] Deploying Pixie."
px deploy --check=false --use_etcd_operator

#echo "[INFO] Listing available demo apps."
#px demo list

#echo "[INFO] Deploying Weaveworks' 'sock-shop'."
#px demo deploy px-sock-shop

#echo "[INFO] Listing built-in scripts."
#px scripts list

#echo "[INFO] Running px/http_data script."
#px live px/http_data

