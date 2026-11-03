#!/usr/bin/env bash
set -eu

for ns in team-red team-blue platform-ns; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# Scan every minute so the lab does not wait an hour for pre-existing Pods.
kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
]'
kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: red-bad
  namespace: team-red
spec:
  containers:
    - name: app
      image: nginx:alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: red-good
  namespace: team-red
  labels:
    team: red
spec:
  containers:
    - name: app
      image: nginx:alpine
      resources:
        limits:
          cpu: 100m
          memory: 64Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: blue-bad
  namespace: team-blue
spec:
  containers:
    - name: app
      image: nginx:alpine
YAML

kubectl wait --for=condition=Ready pod/red-bad pod/red-good -n team-red --timeout=180s
kubectl wait --for=condition=Ready pod/blue-bad -n team-blue --timeout=180s

echo "team-red (red-bad, red-good), team-blue (blue-bad) and platform-ns are ready; no policy exists yet."
