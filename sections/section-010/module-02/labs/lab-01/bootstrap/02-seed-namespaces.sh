#!/usr/bin/env bash
set -eu

for ns in legacy-ns quiet-ns; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-api
  namespace: legacy-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy-api
  template:
    metadata:
      labels:
        app: legacy-api
    spec:
      containers:
        - name: app
          image: nginx:alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: noisy-api
  namespace: quiet-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: noisy-api
  template:
    metadata:
      labels:
        app: noisy-api
    spec:
      containers:
        - name: app
          image: nginx:alpine
EOF

kubectl -n legacy-ns rollout status deployment/legacy-api --timeout=180s
kubectl -n quiet-ns rollout status deployment/noisy-api --timeout=180s

echo "legacy-ns/legacy-api and quiet-ns/noisy-api are running, both without resource limits."
