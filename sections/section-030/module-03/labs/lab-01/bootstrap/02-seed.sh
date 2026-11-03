#!/usr/bin/env bash
set -eu

kubectl create namespace load-ns --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<'YAML'
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
YAML

kubectl wait --for=condition=Ready pod/metrics-probe -n default --timeout=180s

kubectl apply -f - <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: load-require-limits
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-limits
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - load-ns
      validate:
        message: "Every container must set resources.limits.cpu and resources.limits.memory."
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    cpu: "?*"
                    memory: "?*"
YAML

echo "load-ns, the metrics-probe Pod and the Enforce policy load-require-limits are ready. No load has been generated yet."
