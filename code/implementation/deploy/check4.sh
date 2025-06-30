#!/bin/bash

NAMESPACE="vmodel-lab"

# Services and known working ports, using pod fallback if service is missing
# Format: name:type:port:path
# type can be either "svc" or "pod"
SERVICES=(
  "backend-api-service:svc:80:/health"
  "mapping-service:svc:80:/"
  "requirements-service:svc:80:/docs"
  "uml-service:svc:80:/"
)

echo "🔎 Checking service endpoints via port-forward..."

# Function to dynamically fetch pod names
get_pod_name() {
  local service=$1
  kubectl get pods -n $NAMESPACE -l app=vmodel-visualizer,component=$service -o jsonpath="{.items[0].metadata.name}"
}

for entry in "${SERVICES[@]}"; do
  name="${entry%%:*}"
  rest="${entry#*:}"
  type="${rest%%:*}"
  rest="${rest#*:}"
  port="${rest%%:*}"
  path="${rest#*:}"
  local_port=$((RANDOM % 1000 + 8000))

  if [ "$type" == "svc" ]; then
    echo "⏳ Port-forwarding $type/$name (port $port) to localhost:$local_port..."
    kubectl port-forward $type/$name $local_port:$port -n $NAMESPACE > /dev/null 2>&1 &
  else
    pod_name=$(get_pod_name "$name")
    if [ -z "$pod_name" ]; then
      echo "❌ Could not find pod for $name."
      continue
    fi
    echo "⏳ Port-forwarding pod/$pod_name (port $port) to localhost:$local_port..."
    kubectl port-forward pod/$pod_name $local_port:$port -n $NAMESPACE > /dev/null 2>&1 &
  fi

  pf_pid=$!
  sleep 3

  echo "🔁 Curling http://localhost:$local_port$path"
  curl --silent --show-error --fail http://localhost:$local_port$path || echo "❌ Failed to connect to $name"

  kill $pf_pid 2>/dev/null
  wait $pf_pid 2>/dev/null
  echo ""
done

# MySQL port check (not HTTP)
echo "🔎 Checking MySQL TCP port connectivity..."
MYSQL_LOCAL_PORT=$((RANDOM % 1000 + 9000))
kubectl port-forward svc/mysql-service $MYSQL_LOCAL_PORT:3306 -n $NAMESPACE > /dev/null 2>&1 &
pf_pid=$!
sleep 3

if command -v nc >/dev/null 2>&1; then
  nc -zv localhost $MYSQL_LOCAL_PORT && echo "✅ MySQL port is reachable" || echo "❌ MySQL port check failed"
else
  echo "⚠️ 'nc' (netcat) not available. Skipping MySQL TCP check."
fi

kill $pf_pid 2>/dev/null
wait $pf_pid 2>/dev/null
echo ""

echo "✅ External access checks complete."
echo ""

# Internal pod connectivity test
echo "🚀 Entering backend-api pod to test internal service communication..."

POD=$(kubectl get pod -n $NAMESPACE -l "app=vmodel-visualizer,component=backend-api" -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD" ]; then
  echo "❌ Could not find backend-api pod with expected labels."
else
  kubectl exec -n $NAMESPACE "$POD" -- /bin/sh -c "
    echo '🧪 Internal test from backend-api to other services:'
    if ! command -v curl >/dev/null 2>&1; then
      echo 'Installing curl...'
      apk add curl > /dev/null 2>&1
    fi

    for url in \
      'http://requirements-service:8000/docs' \
      'http://uml-service:80/' ; do
        echo Curling \$url...
        curl --fail --silent --show-error \$url || echo '❌ Failed to connect to' \$url
        echo ''
    done

    echo '🔎 Checking internal MySQL port connectivity...'
    if command -v nc >/dev/null 2>&1; then
      nc -zv mysql-service 3306 && echo '✅ Internal MySQL port is reachable' || echo '❌ Internal MySQL port check failed'
    else
      echo '⚠️ nc (netcat) not found inside pod, skipping MySQL check.'
    fi
  "
fi

echo ""
echo "📋 Fetching logs from all pods..."
kubectl get pods -n $NAMESPACE -o name | while read pod; do
  echo "🔍 Logs from $pod:"
  kubectl logs -n $NAMESPACE "$pod" --tail=10
  echo ""
done

echo "✅ All checks done."

