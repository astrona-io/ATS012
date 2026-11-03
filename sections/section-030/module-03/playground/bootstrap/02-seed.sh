#!/usr/bin/env bash
set -eu

for ns in load-ns; do
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
  name: load-require-limits
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
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: seed-ok-1
  namespace: load-ns
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
  name: seed-ok-2
  namespace: load-ns
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
  name: seed-ok-3
  namespace: load-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
      resources:
        limits:
          cpu: 100m
          memory: 64Mi
EOF

# The next two Pods break the policy and are rejected on purpose; that moves the fail counter.
for i in 1 2; do
  kubectl apply -f - >/dev/null 2>&1 <<EOF || true
apiVersion: v1
kind: Pod
metadata:
  name: seed-bad-$i
  namespace: load-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF
done

echo "Playground ready: three admitted and two rejected Pods in load-ns already moved the counters."
