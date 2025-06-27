#!/bin/bash

export PS1="Rashmi$\w\n"
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo ip link delete cni0
sudo ip link delete flannel.1
sudo systemctl stop kubelet
sudo systemctl stop containerd  # If using containerd
sudo systemctl stop docker      # If using Docker
sudo pkill -9 kubelet
sudo pkill -9 etcd
sudo pkill -9 kube-apiserver
sudo pkill -9 kube-controller
sudo pkill -9 kube-scheduler
sudo rm -rf /etc/kubernetes/ /var/lib/etcd /var/lib/kubelet
sudo systemctl restart docker
sudo systemctl restart containerd  # Or restart Docker if using Docker
sudo systemctl restart kubelet

mkdir -p $HOME/.kube
#sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

sudo chmod 644 /etc/kubernetes/admin.conf
sudo chown $(id -u):$(id -g) /etc/kubernetes/admin.conf
export KUBECONFIG=/etc/kubernetes/admin.conf
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

kubectl cluster-info
#sudo kubeadm init --pod-network-cidr=192.168.1.0/16
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
#Thie above command creates .conf file
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
export PATH=$PATH:\home\seed\bin
px auth login
px deploy --check=false
