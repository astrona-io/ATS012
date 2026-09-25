#!/usr/bin/env bash
set -eu

kubectl create namespace metrics-ns --dry-run=client -o yaml | kubectl apply -f -

# A long-lived probe Pod so the metrics endpoint can be scraped from inside the
# cluster with `kubectl exec`, without port-forwarding.
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: metrics-probe
  namespace: default
spec:
  containers:
    - name: curl
      image: curlimages/curl:8.5.0
      command: ["sleep", "infinity"]
      resources:
        limits:
          cpu: "100m"
          memory: "64Mi"
EOF

kubectl wait --for=condition=Ready pod/metrics-probe -n default --timeout=180s

echo "metrics-ns created and metrics-probe is ready in the default namespace."
