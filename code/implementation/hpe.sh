#!/bin/bash 		#imp
export PS1="Rashmi:$\w\n"
sudo systemctl restart docker
minikube delete
minikube start 
#Might need this:
#minikube addons enable storage-provisioner
#minikube addons enable default-storageclass
#install helm:
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
#install pixie on helm:
helm repo add pixie https://storage.googleapis.com/pixie-helm-charts
helm repo update
kubectl config use-context minikube
kubectl cluster-info
kubectl get nodes
kubectl describe node minikube
kubectl get pods -A
helm install px pixie/pixie-chart
kubectl get pods -n default
bash -c "$(curl -fsSL https://withpixie.ai/install.sh)" -- -p /usr/local/bin
px version
export PATH=$PATH:/usr/local/bin
px auth login --manual
px deploy --check=false
px status


