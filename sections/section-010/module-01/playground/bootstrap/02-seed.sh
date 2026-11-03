#!/usr/bin/env bash
set -eu

for ns in platform-ns finance; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
  annotations:
    policies.kyverno.io/severity: high
    policies.kyverno.io/category: Best Practices
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-limits
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - platform-ns
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
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label
  annotations:
    policies.kyverno.io/severity: medium
    policies.kyverno.io/category: Governance
    policies.kyverno.io/scored: "false"
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-team
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - platform-ns
      validate:
        message: "The label team is required."
        pattern:
          metadata:
            labels:
              team: "?*"
EOF

kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-namespace-owner
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-owner
      match:
        any:
        - resources:
            kinds:
              - Namespace
            names:
              - finance
      validate:
        message: "Namespaces must carry the label owner."
        pattern:
          metadata:
            labels:
              owner: "?*"
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: platform-ns
  labels:
    team: "core"
spec:
  containers:
    - name: app
      image: nginx:alpine
      resources:
        limits:
          cpu: 100m
          memory: 64Mi
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: violator-pod
  namespace: platform-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF

kubectl wait --for=condition=Ready pod/compliant-pod pod/violator-pod -n platform-ns --timeout=180s

echo "Playground ready: two Pods in platform-ns and three Audit policies."
