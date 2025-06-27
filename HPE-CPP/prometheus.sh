#!/bin/bash

echo "Setting PS1"
export PS1="Rashmi:$\w\n"

echo "Deleting Minikube cluster..."
minikube delete

echo "Restarting Docker service..."
sudo systemctl restart docker

docker pull registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.2
docker pull quay.io/kiwigrid/k8s-sidecar:1.30.0
docker pull grafana/grafana:11.6.0
docker pull quay.io/prometheus-operator/prometheus-config-reloader:v0.81.0

minikube start --host-dns-resolver=false --cache-images

kubectl create namespace monitoring

helm install  prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring
helm upgrade --reuse-values prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set nodeExporter.extraArgs="{--collector.textfile.directory=/textfile-collector}" \
  --set nodeExporter.hostRootFsMount=false \
  --set nodeExporter.extraHostPathMounts[0].name=textfile-metrics \
  --set nodeExporter.extraHostPathMounts[0].hostPath=/var/lib/node_exporter/textfile_collector \
  --set nodeExporter.extraHostPathMounts[0].mountPath=/textfile-collector \
  --set nodeExporter.extraHostPathMounts[0].readOnly=false

kubectl get pods -n monitoring
kubectl get svc -n monitoring

echo "need to add - --collector.textfile.directory=/textfile-collector
under args '- name: textfile-metrics
  mountPath: /textfile-collector
  readOnly: false
' under volumeMounts and '- name: textfile-metrics
  hostPath:
    path: /var/lib/node_exporter/textfile_collector
' under volumes"

echo "IMPORTANT previous step needs to followed no changes allowed to that step!"

kubectl edit daemonset prometheus-prometheus-node-exporter -n monitoring

echo "enter minikube shell and execute 'sudo mkdir -p /var/lib/node_exporter/textfile_collector
echo 'iscsi_dummy_metric{lun="test"} 1' | sudo tee /var/lib/node_exporter/textfile_collector/iscsi.prom 'sudo tee /usr/local/bin/iscsi_metrics.sh > /dev/null << 'EOF'
#!/bin/bash

OUTPUT="/var/lib/node_exporter/textfile_collector/iscsi_metrics.prom"
exec > "$OUTPUT"
exec 2>&1

echo "# HELP iscsi_lun_read_kbps Read KB/s from iSCSI LUN"
echo "# TYPE iscsi_lun_read_kbps gauge"

read_kbps=$(iostat -d /dev/sda | awk 'NR==4 {print $3}')
echo "iscsi_lun_read_kbps{device=\"sda\"} $read_kbps"

echo "# HELP iscsi_lun_write_kbps Write KB/s from iSCSI LUN"
echo "# TYPE iscsi_lun_write_kbps gauge"

write_kbps=$(iostat -d /dev/sda | awk 'NR==4 {print $4}')
echo "iscsi_lun_write_kbps{device=\"sda\"} $write_kbps"
EOF
'
''sudo apt install -y sysstat' 'sudo apt-get install -y cron' 'sudo service cron start
' 'sudo service cron start
' 'sudo systemctl enable cron
' 'sudo crontab -e
=> then add * * * * * /usr/local/bin/iscsi_metrics.sh
' 'cat /var/lib/node_exporter/textfile_collector/iscsi_metrics.prom
'"
minikube ssh
# Prometheus UI
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090

echo "Do Go to the "Graph" tab.

Enter iscsi_lun_read_kbps or iscsi_lun_write_kbps in the expression field to see the metrics being collected."


# Grafana UI
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

echo "execute after 'kubectl port-forward prometheus-prometheus-node-exporter-<id> 9100:9100 -n monitoring
'"

curl -s http://localhost:9100/metrics | grep iscsi_dummy_metric

