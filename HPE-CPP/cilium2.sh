#!/bin/bash

echo "Setting PS1"
export PS1="Rashmi:$\w\n"

echo "Deleting Minikube cluster..."
minikube delete

echo "Restarting Docker service..."
sudo systemctl restart docker

# Pull images manually
echo "Pulling Cilium images..."
docker pull quay.io/cilium/cilium:v1.17.2@sha256:3c4c9932b5d8368619cb922a497ff2ebc8def5f41c18e410bcc84025fcd385b1
docker pull quay.io/cilium/cilium-envoy:v1.31.5-1741765102-efed3defcc70ab5b263a0fc44c93d316b846a211@sha256:377c78c13d2731f3720f931721ee309159e782d882251709cb0fac3b42c03f4b
docker pull quay.io/cilium/operator-generic:v1.17.2@sha256:81f2d7198366e8dec2903a3a8361e4c68d47d19c68a0d42f0b7b6e3f0523f249

echo "Pulling CoreDNS and ETCD images..."
docker pull registry.k8s.io/coredns/coredns:v1.11.3
docker pull registry.k8s.io/etcd:3.5.16-0

echo "Pulling Hubble images..."
docker pull quay.io/cilium/hubble-relay:v1.17.2@sha256:42a8db5c256c516cacb5b8937c321b2373ad7a6b0a1e5a5120d5028433d586cc
docker pull quay.io/cilium/hubble-ui:v0.13.2@sha256:9e37c1296b802830834cc87342a9182ccbb71ffebb711971e849221bd9d59392
docker pull quay.io/cilium/hubble-ui-backend:v0.13.2@sha256:a034b7e98e6ea796ed26df8f4e71f83fc16465a19d166eff67a03b822c0bfa15

echo "Starting Minikube with Cilium..."
minikube start --cni=cilium --host-dns-resolver=false --cache-images

echo "update minikube context"
minikube update-context

# Add images to Minikube cache
echo "Caching Cilium images in Minikube..."
minikube image load quay.io/cilium/cilium:v1.17.2
minikube image load quay.io/cilium/cilium-envoy:v1.31.5-1741765102-efed3defcc70ab5b263a0fc44c93d316b846a211
minikube image load quay.io/cilium/operator-generic:v1.17.2
minikube image load registry.k8s.io/coredns/coredns:v1.11.3
minikube image load registry.k8s.io/etcd:3.5.16-0
minikube image load quay.io/cilium/hubble-relay:v1.17.2
minikube image load quay.io/cilium/hubble-ui:v0.13.2
minikube image load quay.io/cilium/hubble-ui-backend:v0.13.2

echo "Delete all previous traces"
kubectl delete daemonset cilium -n kube-system
kubectl delete daemonset cilium-envoy -n kube-system
kubectl delete deployment cilium-operator -n kube-system

kubectl delete clusterrolebinding cilium
kubectl delete clusterrole cilium
kubectl delete clusterrolebinding cilium-operator
kubectl delete clusterrole cilium-operator
kubectl delete serviceaccount cilium -n kube-system
kubectl delete serviceaccount cilium-envoy -n kube-system
kubectl delete serviceaccount cilium-operator -n kube-system

kubectl delete configmap cilium-envoy-config -n kube-system
kubectl delete configmap cilium-config -n kube-system

kubectl delete role cilium-config-agent -n kube-system
kubectl delete rolebinding cilium-config-agent -n kube-system

kubectl delete service hubble-peer -n kube-system
kubectl delete svc cilium-envoy -n kube-system

echo "restart with helm"
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true

echo "Restart cilium"
kubectl rollout restart deployment cilium-operator -n kube-system

echo "Checking Cilium status..."
cilium status --wait

echo "Enabling Hubble..."
cilium hubble enable

echo "Checking Hubble status..."
hubble status

echo "Starting Hubble port-forward..."
cilium hubble port-forward &

echo "Observing Hubble traffic..."
hubble observe

