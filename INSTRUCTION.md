# Deployment & Validation Instructions

## Prerequisites

- [`kind`](https://kind.sigs.k8s.io/) installed
- `kubectl` installed and configured
- Docker running locally

---

## 1. Spin up the local cluster

```bash
kind create cluster --config cluster.yml
```

Verify the cluster is running:

```bash
kubectl cluster-info
kubectl get nodes
```

---

## 2. Deploy all resources

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

The script will apply every manifest in order, waiting for MySQL to become ready before starting the application.

---

## 3. Validate MySQL StatefulSet

### Check pods are running (expect 3)
```bash
kubectl get pods -n mysql
```
Expected output:
```
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   1/1     Running   0          ...
mysql-1   1/1     Running   0          ...
mysql-2   1/1     Running   0          ...
```

### Confirm PVCs were created automatically (one per pod)
```bash
kubectl get pvc -n mysql
```

### Check the headless service exists
```bash
kubectl get svc mysql -n mysql
# CLUSTER-IP should show "None"
```

### Verify DNS resolution inside the cluster
```bash
kubectl run -it --rm dns-test --image=busybox --restart=Never -n mysql -- \
  nslookup mysql-0.mysql.mysql.svc.cluster.local
```

### Connect to the primary pod and confirm the database was initialised
```bash
kubectl exec -it mysql-0 -n mysql -- \
  mysql -u todouser -ptodopassword -e "SHOW DATABASES; USE tododb; SHOW TABLES;"
```

### Inspect liveness / readiness probe status
```bash
kubectl describe pod mysql-0 -n mysql | grep -A 10 "Liveness\|Readiness"
```

---

## 4. Validate the todoapp Deployment

### Check pods are running (HPA min = 2)
```bash
kubectl get pods -n todoapp
```

### Confirm the app can reach the DB (check logs for migration success)
```bash
kubectl logs -n todoapp -l app=todoapp --tail=50
```

### Verify all environment variables are injected from the secret
```bash
kubectl exec -n todoapp \
  $(kubectl get pod -n todoapp -l app=todoapp -o jsonpath='{.items[0].metadata.name}') \
  -- env | grep -E "DB_|SECRET_KEY"
```

### Test the health and readiness endpoints
```bash
# Forward a local port to the ClusterIP service
kubectl port-forward svc/todoapp-service 8080:80 -n todoapp &

curl -s http://localhost:8080/api/health
curl -s http://localhost:8080/api/ready
```

### Access via NodePort (port 30007)
```bash
# Get the node's internal IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl -s http://${NODE_IP}:30007/api/health
```

### Validate HPA is active
```bash
kubectl get hpa -n todoapp
```

---

## 5. Validate Secrets are not exposed in plain text

```bash
# Secret data should be base64 encoded, not plain text
kubectl get secret app-secret -n todoapp -o yaml
kubectl get secret mysql-secret -n mysql -o yaml
```

---

## 6. Clean up

```bash
kind delete cluster
```