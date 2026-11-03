#!/usr/bin/env bash
set -eu

for ns in team-red team-blue; do
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
              - team-red
              - team-blue
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
              - team-red
              - team-blue
      validate:
        message: "The label team is required."
        pattern:
          metadata:
            labels:
              team: "?*"
EOF

kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
]'
for d in kyverno-reports-controller; do
  kubectl -n kyverno rollout status "deployment/${d}" --timeout=180s
done

kubectl apply -f - <<'EOF'
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
    team: "red"
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
EOF

kubectl wait --for=condition=Ready pod/red-bad pod/red-good -n team-red --timeout=180s
kubectl wait --for=condition=Ready pod/blue-bad -n team-blue --timeout=180s

echo "Playground ready: two annotated Audit policies (severity high and medium) and three Pods across team-red and team-blue."
