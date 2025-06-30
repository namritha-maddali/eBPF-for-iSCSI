#!/bin/bash

echo "enter required directory"
cd /home/seed/Downloads/HPE-CPP/deploy

echo "[INFO] Setting PS1 prompt."
export PS1="Rashmi$\w\n"

echo "========================STAGE 1: Create the LUN=================================="
gnome-terminal -- bash -c "echo 'STAGE 1: Create the LUN'; source /home/seed/Downloads/HPE-CPP/LUN.sh;exit;"

echo "==========================STAGE 2: Clear all previous traces of k8s==================" 
echo "Uninstall that version on helm"
helm uninstall vmodel -n vmodel-lab

echo "[INFO] Resetting Kubernetes cluster."
sudo kubeadm reset -f
sudo sysctl -w kernel.core_pattern=|/bin/false

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

echo "Logout of LUN and unmount it"
sudo iscsiadm -m node --logout
sudo umount /dev/sdb /mnt/data/mysql/mysql3

echo "==============================STAGE 3: RESTART KUBERNETES=================================="
echo "[INFO] Restarting Docker service."
sudo systemctl restart docker

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

echo "===============================STAGE 4: CREATE PV'S and Run all pods==============================="
echo "create vmodel-lab namespace"
kubectl create namespace vmodel-lab

echo "[INFO] Forcibly removing and resetting /mnt/data/mysql again before Helm install..."
sudo umount /mnt/data/mysql 2>/dev/null || true         # If mounted by previous pod
sudo rm -rf /mnt/data/mysql
sudo mkdir -p /mnt/data/mysql
sudo chown -R 999:999 /mnt/data/mysql
sudo chmod 700 /mnt/data/mysql
sudo ls -la /mnt/data/mysql

echo "Trying to mount iSCSI LUN"
echo "[INFO] Discovering and logging into iSCSI LUN target"
sudo iscsiadm -m discovery -t sendtargets -p 127.0.0.1
sudo iscsiadm -m node --login

echo "Clear LUN data before mounting"
sudo mkdir -p /mnt/temp_lun
sudo mount /dev/sdb /mnt/temp_lun
sudo rm -rf /mnt/temp_lun/*
sudo rm -rf /mnt/temp_lun/.* 2>/dev/null || true
sudo ls -la /mnt/temp_lun
sudo umount /mnt/temp_lun

echo "Create separate hostPaths for PV's"
sudo mkdir -p /mnt/data/mysql/mysql{1,2,3}
sudo chown -R 999:999 /mnt/data/mysql/mysql{1,2,3}
echo "content in hostPaths for PV's"
sudo ls -ld /mnt/data/mysql/mysql{1,2,3}

#echo "Trying to mount iSCSI LUN"
#echo "[INFO] Discovering and logging into iSCSI LUN target"
#sudo iscsiadm -m discovery -t sendtargets -p 127.0.0.1
#sudo iscsiadm -m node --login
#sleep 5
#sudo mount /dev/sdb /mnt/data/mysql/mysql1

echo "Create storage-classes"
kubectl apply -f standard-requirements-sc.yaml -n vmodel-lab
kubectl apply -f standard-sc.yaml -n vmodel-lab
kubectl apply -f standard-uml-sc.yaml -n vmodel-lab

echo "Create persistent volumes"
kubectl apply -f pv-mysql.yaml  -n vmodel-lab
kubectl apply -f pv-requirements-mysql.yaml -n vmodel-lab
kubectl apply -f pv-uml-mysql.yaml -n vmodel-lab

echo "content in hostPaths for PV's after creation"
sudo ls -ld /mnt/data/mysql/mysql{1,2,3}

echo "Checking LUN mounted"
lsblk

echo "DEPLOY..."
helm install vmodel . -n vmodel-lab

echo "Upgrade just in case"
helm upgrade vmodel . -n vmodel-lab

echo "List storageclasses"
kubectl get storageclass

echo "List persistent volumes"
kubectl get pv -n vmodel-lab

echo "List persistent volume claims"
kubectl get pvc -n vmodel-lab

echo "List the pods"
kubectl get pods -n vmodel-lab

echo "List the services"
kubectl get svc -n vmodel-lab

echo "===================STAGE 5: Set up Prometheus and Grafana===================="
echo "Pulling required images for Prometheus and Grafana"
docker pull registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.2
docker pull quay.io/kiwigrid/k8s-sidecar:1.30.0
docker pull grafana/grafana:11.6.0
docker pull quay.io/prometheus-operator/prometheus-config-reloader:v0.81.0

echo "Create namespace monitoring"
kubectl create namespace monitoring

echo "Install Helm chart for prometheus and grafana"
helm install  prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring

echo "List pods in namespace monitoring"
kubectl get pods -n monitoring

echo "List services in namespace monitoring"
kubectl get svc -n monitoring

echo "Grafana's admin password:"
kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

sleep 10

echo "Finally port-forward all services"
source /home/seed/Downloads/HPE-CPP/deploy/port-forward.sh
