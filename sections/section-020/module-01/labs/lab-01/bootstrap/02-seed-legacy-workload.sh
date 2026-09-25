#!/usr/bin/env bash
set -eu

for ns in legacy-ns platform-ns; do
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
EOF

kubectl -n legacy-ns rollout status deployment/legacy-api --timeout=180s

echo "legacy-ns/legacy-api (no resource limits) is running; platform-ns is ready to hold exceptions."
