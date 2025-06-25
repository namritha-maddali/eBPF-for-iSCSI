# eBPF-for-iSCSI
## Architecture Diagram
![image](https://github.com/user-attachments/assets/a263f792-ea32-4b66-a474-c56efa1d2429)

## Prerequisites

- Make sure both the VMs have static and different IP addresses.
- Linux-based environment with at least 2 cores and 2GB RAM.

---

## Step 1: Setup Kubernetes Cluster with Two Nodes

Create a Kubernetes cluster with two nodes (1 control-plane, 1 worker).

---

## Step 2: Install Cilium

```bash
helm repo add cilium https://helm.cilium.io/

helm install cilium cilium/cilium --version 1.12.19 \
   --namespace kube-system \
   --set prometheus.enabled=true \
   --set operator.prometheus.enabled=true \
   --set hubble.enabled=true \
   --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}"
```

---

## Step 3: Enable Prometheus and Grafana for Cilium Metrics

Apply the monitoring configuration:

```bash
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.12/examples/kubernetes/addons/prometheus/monitoring-example.yaml
```

---

## Step 4: Set Up Persistent Volume (PVC) Using Target Disk

```bash
kubectl apply -f iscsi-pv.yaml
kubectl apply -f iscsi-pvc.yaml
```

---

## Step 5: Visualize Networking Metrics with Prometheus and Grafana

### Prometheus

```bash
kubectl -n cilium-monitoring port-forward service/prometheus --address 0.0.0.0 --address :: 9090:9090
```

Access Prometheus at: [http://<your-ip>:9090](http://<your-ip>:9090)

### Grafana

```bash
kubectl -n cilium-monitoring port-forward service/grafana --address 0.0.0.0 --address :: 3000:3000
```

Access Grafana at: [http://<your-ip>:3000](http://<your-ip>:3000)

---
