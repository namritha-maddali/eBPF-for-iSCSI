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

echo "Setup LUN..."
sudo source /home/user/Downloads/HPE-CPP/LUN.sh

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
sleep 15
sudo crontab -e

echo "Check whether it worked"
sudo /usr/local/bin/iscsi_metrics.sh
cat /usr/local/bin/node_exporter/textfile_collector/iscsi.prom

sleep 5

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

