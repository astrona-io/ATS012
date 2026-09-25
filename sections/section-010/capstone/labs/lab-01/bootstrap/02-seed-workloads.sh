#!/usr/bin/env bash
set -eu

for ns in prod-ns staging-ns; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing-api
  namespace: prod-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: billing-api
  template:
    metadata:
      labels:
        app: billing-api
    spec:
      containers:
        - name: app
          image: nginx:alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-api
  namespace: staging-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: checkout-api
  template:
    metadata:
      labels:
        app: checkout-api
    spec:
      containers:
        - name: app
          image: nginx:alpine
          resources:
            limits:
              cpu: "100m"
              memory: "128Mi"
EOF

kubectl -n prod-ns rollout status deployment/billing-api --timeout=180s
kubectl -n staging-ns rollout status deployment/checkout-api --timeout=180s

echo "prod-ns/billing-api (no limits, no team label) and staging-ns/checkout-api (limits set, no team label) are running."
