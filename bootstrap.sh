#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# bootstrap.sh — Deploy all Kubernetes resources for the ToDo app + MySQL
###############################################################################

echo "==> Creating namespaces..."
kubectl apply -f .infrastructure/mysql_namespace.yml
kubectl apply -f .infrastructure/namespace.yml

echo "==> Applying MySQL secrets and config..."
kubectl apply -f .infrastructure/mysql_secret.yml
kubectl apply -f .infrastructure/mysql_configmap.yml

echo "==> Deploying MySQL StatefulSet (+ headless Service)..."
kubectl apply -f .infrastructure/statefulSet.yml

echo "==> Waiting for MySQL pods to be ready (up to 3 minutes)..."
kubectl rollout status statefulset/mysql -n mysql --timeout=180s

echo "==> Applying todoapp secrets and config..."
kubectl apply -f .infrastructure/app_secret.yml
kubectl apply -f .infrastructure/configMap.yml

echo "==> Applying PersistentVolume and PersistentVolumeClaim..."
kubectl apply -f .infrastructure/pv.yml
kubectl apply -f .infrastructure/pvc.yml

echo "==> Deploying todoapp..."
kubectl apply -f .infrastructure/deployment.yml

echo "==> Applying Services and HPA..."
kubectl apply -f .infrastructure/clusterIp.yml
kubectl apply -f .infrastructure/nodeport.yml
kubectl apply -f .infrastructure/hpa.yml

echo "==> Waiting for todoapp deployment to be ready..."
kubectl rollout status deployment/todoapp -n todoapp --timeout=180s

echo ""
echo "✅ All resources deployed successfully!"
echo ""
echo "Access the app via NodePort:"
kubectl get svc todoapp-nodeport -n todoapp