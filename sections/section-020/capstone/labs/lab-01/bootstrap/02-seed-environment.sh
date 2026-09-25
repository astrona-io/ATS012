#!/usr/bin/env bash
set -eu

for ns in prod-ns platform-ns rogue-ns; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-api
  namespace: prod-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments-api
  template:
    metadata:
      labels:
        app: payments-api
    spec:
      containers:
        - name: app
          image: nginx:alpine
EOF

kubectl -n prod-ns rollout status deployment/payments-api --timeout=180s

echo "prod-ns/payments-api (no resource limits) is running; platform-ns and rogue-ns are ready."
