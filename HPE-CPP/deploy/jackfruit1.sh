#!/bin/bash

echo "enter required directory"
cd /home/user/Downloads/HPE-CPP/deploy

echo "[INFO] Setting PS1 prompt."
export PS1="Rashmi$\w\n"

echo "========================STAGE 1: Create the LUN=================================="
#gnome-terminal -- bash -c "echo 'STAGE 1: Create the LUN'; source /home/user/Downloads/HPE-CPP/LUN.sh;"
#source /home/user/Downloads/HPE-CPP/LUN.sh
# Start an interactive tmux session and pause the main script until it's done

tmux new-session -d -s stage1 "bash -c 'echo STAGE 1: Create the LUN; source /home/user/Downloads/HPE-CPP/LUN.sh; read -p \"Press Enter to close this window...\"'"
tmux attach -t stage1

#sleep 30 

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
sudo umount /dev/sdc /mnt/data/mysql/mysql3
sudo iscsiadm -m node --logout

echo "==============================STAGE 3: RESTART KUBERNETES=================================="
echo "[INFO] Restarting Docker service."
sudo systemctl restart docker

echo "[INFO] Restarting kubelet service."
sudo systemctl restart kubelet

echo "[INFO] Initializing Kubernetes cluster with Cilium network."
sudo kubeadm init --pod-network-cidr=10.0.0.0/16

#sleep 15

#JOIN_CMD=$(sudo kubeadm token create --print-join-command)
#echo "Before ssh: $JOIN_CMD"

#echo "[INFO] Running worker setup script remotely..."
#ssh seed@192.168.1.10 "export JOIN_CMD='$JOIN_CMD'; bash /home/seed/Downloads/HPE-CPP/deploy/worker.sh '$JOIN_CMD'"

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

echo "Check if worker node joined?"
kubectl get nodes

echo "[INFO] Removing taints from control plane nodes."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

#echo "[INFO] Applying Flannel CNI network."
#kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo "==========================STAGE 4: Apply Cilium==========================="
echo "[INFO] Apply Cilium CNI Network"
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
#helm upgrade --install cilium cilium/cilium \
 # --namespace kube-system \
 # --set hubble.relay.enabled=true \
 # --set hubble.ui.enabled=true
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true \
  --set hubble.enabled=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}" \
  --set hubble.metrics.enableOpenMetrics=true

echo "Starting service to scrape Cilium for Prometheus and Grafana:"
kubectl apply -f cilium-metrics-service.yaml

echo "===============================STAGE 5: CREATE PV'S and Run all pods==============================="

echo "[INFO] Checking if persistent volumes are available."
kubectl get storageclass

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
sudo iscsiadm -m discovery -t sendtargets -p 10.10.3.111
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

echo "Trying to mount iSCSI LUN"
echo "[INFO] Discovering and logging into iSCSI LUN target"
sudo iscsiadm -m discovery -t sendtargets -p 10.10.3.111
sudo iscsiadm -m node --login
#sleep 5
#sudo mount /dev/sdb /mnt/data/mysql/mysql1

echo "Clear LUN data before mounting"
sudo mkdir -p /mnt/temp_lun
sudo mount /dev/sdc /mnt/temp_lun
sudo rm -rf /mnt/temp_lun/*
sudo rm -rf /mnt/temp_lun/.* 2>/dev/null || true
sudo ls -la /mnt/temp_lun
sudo umount /mnt/temp_lun

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

echo "Waiting to setup worker node"
sleep 15

JOIN_CMD=$(sudo kubeadm token create --print-join-command)
echo "Before ssh: $JOIN_CMD"

echo "[INFO] Running worker setup script remotely..."
ssh -t user@10.10.3.113 "export JOIN_CMD='$JOIN_CMD'; bash /home/user/Downloads/HPE-CPP/deploy/worker.sh '$JOIN_CMD'"

echo "Assign role of worker to vm-clone"
kubectl label node vm-clone node-role.kubernetes.io/worker=""

echo "Check status of nodes"
kubectl get nodes

echo "=====================STAGE 5: Expose metrics from the LUN (Storage metrics)======================"

echo "Gathering iscsi metrics straight from the source"
sudo tee /usr/local/bin/iscsi_metrics.sh > /dev/null << 'EOF'
#!/bin/bash

OUTPUT="/usr/local/bin/node_exporter/textfile_collector/iscsi.prom"
exec > "$OUTPUT"
exec 2>&1

echo "# HELP iscsi_scsi_tgt_port Metrics from iSCSI target port"
echo "# TYPE iscsi_scsi_tgt_port gauge"

BASE="/sys/kernel/config/target/iscsi/iqn.2025-06.com.example:uml/tpgt_1/lun/lun_0/statistics/scsi_tgt_port"
for file in "$BASE"/*; do
    name=$(basename "$file" | tr '-' '_' | tr ' ' '_')
    value=$(cat "$file")
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "iscsi_scsi_tgt_port_${name} $value"
    else
        safe_value=$(echo "$value" | sed 's/"/\\"/g')
        echo "iscsi_scsi_tgt_port_${name}{value=\"$safe_value\"} 1"
    fi
done

echo "# HELP iscsi_scsi_port Metrics from iSCSI port"
echo "# TYPE iscsi_scsi_port gauge"

BASE_PORT="/sys/kernel/config/target/iscsi/iqn.2025-06.com.example:uml/tpgt_1/lun/lun_0/statistics/scsi_port"
for file in "$BASE_PORT"/*; do
    name=$(basename "$file" | tr '-' '_' | tr ' ' '_')
    value=$(cat "$file")
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "iscsi_scsi_port_${name} $value"
    else
        safe_value=$(echo "$value" | sed 's/"/\\"/g')
        echo "iscsi_scsi_port_${name}{value=\"$safe_value\"} 1"
    fi
done

echo "# HELP iscsi_scsi_transport Metrics from iSCSI transport"
echo "# TYPE iscsi_scsi_transport gauge"

BASE_TRANS="/sys/kernel/config/target/iscsi/iqn.2025-06.com.example:uml/tpgt_1/lun/lun_0/statistics/scsi_transport"
for file in "$BASE_TRANS"/*; do
    name=$(basename "$file" | tr '-' '_' | tr ' ' '_')
    value=$(cat "$file")
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "iscsi_scsi_transport_${name} $value"
    else
        safe_value=$(echo "$value" | sed 's/"/\\"/g')
        echo "iscsi_scsi_transport_${name}{value=\"$safe_value\"} 1"
    fi
done
EOF

sudo chmod +x /usr/local/bin/iscsi_metrics.sh

echo "Setting it up as a cronjob"
sudo apt install -y sysstat
sudo apt-get install -y cron
sudo service cron start
sudo systemctl enable cron

echo "then add * * * * * /usr/local/bin/iscsi_metrics.sh"
sleep 20
sudo crontab -e

echo "Check whether it worked"
sudo /usr/local/bin/iscsi_metrics.sh
cat /usr/local/bin/node_exporter/textfile_collector/iscsi.prom

echo "Use this to create service 'Save this file as /etc/systemd/system/iscsi_bcc.service
[Unit]
Description=iSCSI eBPF Metrics Collector (BCC)
After=network.target
[Service]
ExecStart=/usr/bin/python3 /home/user/Downloads/HPE-CPP/bcc_file.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target'"

echo "[INFO] Restrarting service for bcc program"
sudo systemctl daemon-reload
sudo systemctl enable --now iscsi_bcc.service
sudo systemctl restart iscsi_bcc.service
systemctl status iscsi_bcc.service

echo "Check output:"
cat /usr/local/bin/node_exporter/textfile_collector/iscsi_metrics.prom

echo "---------STAGE 6: Set up Prometheus and Grafana------------------"
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

echo "Add a service-monitor for Cilium"
kubectl apply -f cilium-servicemonitor.yaml

echo "List pods in namespace monitoring"
kubectl get pods -n monitoring

echo "List services in namespace monitoring"
kubectl get svc -n monitoring

echo "Grafana's admin password:"
kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

echo "Wait for all pods to come up"
sleep 120

echo "Restart core-DNS just in case..."
kubectl delete pod -n kube-system -l k8s-app=kube-dns

gnome-terminal -- bash -c "echo '[PATCH] Change uml-backend deployment';echo 'need to add - --collector.textfile.directory=/textfile-collector
under args '- name: textfile-metrics
  mountPath: /textfile-collector
  readOnly: false
' under volumeMounts and '- name: textfile-metrics
  hostPath:
    path: /var/lib/node_exporter/textfile_collector
' under volumes';exec bash;
"
kubectl edit daemonset prometheus-prometheus-node-exporter -n monitoring

gnome-terminal -- bash -c "echo '[PATCH] edit uml-mysql after it loads fully';echo 'use uml;
ALTER TABLE diagrams ADD COLUMN user_id VARCHAR(255);
ALTER TABLE diagrams
  CHANGE COLUMN name title VARCHAR(255);
ALTER TABLE diagrams
    ADD COLUMN description TEXT,
    MODIFY COLUMN title VARCHAR(255),
    MODIFY COLUMN content TEXT,
    MODIFY COLUMN user_id VARCHAR(255);
ALTER TABLE diagrams ADD COLUMN uml_syntax TEXT;
';export KUBECONFIG=/etc/kubernetes/admin.conf;kubectl get pods -n vmodel-lab;exec bash;"

echo "Final check:"
kubectl get pods -A
kubectl get nodes

sleep 5

echo "[INFO] Checking storage metrics"
curl http://localhost:9100/metrics | grep iscsi

sleep 5

echo "[INFO] Checking networking metrics"
curl http://localhost:9100/metrics | grep cilium

sleep 5

echo "[INFO] for Grafana: To add datasource use 'http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090'. And for the Cilium metrics custom dashboard import dashboard of ID 6658"

echo "Finally port-forward all services"
source /home/user/Downloads/HPE-CPP/deploy/port-forward1.sh
