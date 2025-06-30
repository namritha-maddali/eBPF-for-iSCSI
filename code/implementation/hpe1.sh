#!/bin/bash 		#imp

export PS1="Rashmi:$\w\n"

# Restart Docker
sudo systemctl restart docker

# Delete and Start Minikube
minikube delete
minikube start --memory=8000 --cpus=4 --driver=kvm2

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

export PX_CLOUD_ADDR=getcosmic.ai

# Install Pixie on Helm
helm repo add pixie https://storage.googleapis.com/pixie-helm-charts
helm repo update

# Set Kubernetes Context
kubectl config use-context minikube
kubectl cluster-info
kubectl get nodes
kubectl describe node minikube

px auth login --manual
# Install Pixie via Helm
helm install px pixie/pixie-chart

# Wait for all pods in the default namespace to be in Running state
echo "Waiting for all pods in the default namespace to be Running..."
while true; do
    NOT_RUNNING=$(kubectl get pods -n default --no-headers | grep -v 'Running' | wc -l)
    if [[ "$NOT_RUNNING" -eq 0 ]]; then
        echo "All pods are running!"
        break
    else
        echo "Waiting for pods to be ready... ($NOT_RUNNING pods not ready)"
        sleep 60  # Wait for 5 seconds before checking again
    fi
done

# Install Pixie CLI
bash -c "$(curl -fsSL https://withpixie.ai/install.sh)" -- -p /usr/local/bin
px version

# Export PATH
export PATH=$PATH:/usr/local/bin

# Authenticate Pixie
#px auth login --manual

# Deploy Pixie
px deploy --check=false

# Check Pixie Status
px status

