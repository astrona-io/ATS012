#!/usr/bin/env bash
set -eu

for ns in watched-ns excluded-ns; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

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

echo "Playground ready: watched-ns, excluded-ns and metrics-probe exist; the kyverno-metrics ConfigMap still has its shipped values."
