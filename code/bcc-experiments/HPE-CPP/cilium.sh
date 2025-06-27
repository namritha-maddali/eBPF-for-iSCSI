#!/bin/bash

#kubectl delete crd -l io.cilium.k8s.policy
#kubectl delete crd ciliumnetworkpolicies.cilium.io
#kubectl delete crd ciliumendpoints.cilium.io
#kubectl delete crd ciliumidentities.cilium.io
#kubectl delete crd ciliumnodes.cilium.io
#kubectl delete crd ciliumclusterwidenetworkpolicies.cilium.io
#kubectl delete crd ciliumnetworkpolicies.cilium.io

#kubectl delete all -l k8s-app=cilium -n kube-system
#kubectl delete clusterrolebinding cilium
#kubectl delete clusterrole cilium
#kubectl delete serviceaccount cilium -n kube-system

minikube delete
sudo systemctl restart docker

docker pull quay.io/cilium/cilium:v1.17.2@sha256:3c4c9932b5d8368619cb922a497ff2ebc8def5f41c18e410bcc84025fcd385b1
docker pull quay.io/cilium/cilium-envoy:v1.31.5-1741765102-efed3defcc70ab5b263a0fc44c93d316b846a211@sha256:377c78c13d2731f3720f931721ee309159e782d882251709cb0fac3b42c03f4b
docker pull quay.io/cilium/operator-generic:v1.17.2@sha256:81f2d7198366e8dec2903a3a8361e4c68d47d19c68a0d42f0b7b6e3f0523f249
docker pull registry.k8s.io/coredns/coredns:v1.11.3
docker pull registry.k8s.io/etcd:3.5.16-0
docker pull quay.io/cilium/hubble-relay:v1.17.2@sha256:42a8db5c256c516cacb5b8937c321b2373ad7a6b0a1e5a5120d5028433d586cc
docker pull quay.io/cilium/hubble-ui:v0.13.2@sha256:9e37c1296b802830834cc87342a9182ccbb71ffebb711971e849221bd9d59392
docker pull quay.io/cilium/hubble-ui-backend:v0.13.2@sha256:a034b7e98e6ea796ed26df8f4e71f83fc16465a19d166eff67a03b822c0bfa15

minikube cache add quay.io/cilium/cilium:v1.17.2@sha256:3c4c9932b5d8368619cb922a497ff2ebc8def5f41c18e410bcc84025fcd385b1
minikube cache add quay.io/cilium/cilium-envoy:v1.31.5-1741765102-efed3defcc70ab5b263a0fc44c93d316b846a211@sha256:377c78c13d2731f3720f931721ee309159e782d882251709cb0fac3b42c03f4b
minikube cache add quay.io/cilium/operator-generic:v1.17.2@sha256:81f2d7198366e8dec2903a3a8361e4c68d47d19c68a0d42f0b7b6e3f0523f249
minikube cache add registry.k8s.io/coredns/coredns:v1.11.3
minikube cache add registry.k8s.io/etcd:3.5.16-0
minikube cache add quay.io/cilium/hubble-relay:v1.17.2@sha256:42a8db5c256c516cacb5b8937c321b2373ad7a6b0a1e5a5120d5028433d586cc
minikube cache add quay.io/cilium/hubble-ui:v0.13.2@sha256:9e37c1296b802830834cc87342a9182ccbb71ffebb711971e849221bd9d59392
minikube cache add quay.io/cilium/hubble-ui-backend:v0.13.2@sha256:a034b7e98e6ea796ed26df8f4e71f83fc16465a19d166eff67a03b822c0bfa15

minikube start --cni=cilium --host-dns-resolver=false --cache-images
#CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
#CLI_ARCH=amd64
#if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
#cilium install --version 1.17.2

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
kubectl delete service cilium-envoy -n kube-system

#helm uninstall cilium -n kube-system
#helm install cilium cilium/cilium --version 1.17.2 --namespace kube-system --set hubble.relay.enabled=true --set hubble.ui.enabled=true

#cilium restart
cilium status
cilium hubble enable
hubble status
cilium hubble port-forward&
hubble observe

