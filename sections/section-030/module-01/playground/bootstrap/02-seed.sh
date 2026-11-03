#!/usr/bin/env bash
set -eu

for ns in metrics-ns; do
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

kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: metrics-demo-limits
  annotations:
    policies.kyverno.io/severity: high
    policies.kyverno.io/category: Best Practices
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
              - metrics-ns
      validate:
        message: "Every container must set resources.limits.cpu and resources.limits.memory."
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    cpu: "?*"
                    memory: "?*"
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: metrics-pass-pod
  namespace: metrics-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
      resources:
        limits:
          cpu: 100m
          memory: 64Mi
EOF

kubectl wait --for=condition=Ready pod/metrics-pass-pod -n metrics-ns --timeout=180s

echo "Playground ready: scrape with kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics"
