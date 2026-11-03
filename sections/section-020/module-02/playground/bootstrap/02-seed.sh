#!/usr/bin/env bash
set -eu

for ns in batch-ns platform-ns; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl -n kyverno patch deployment kyverno-admission-controller --type=json -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enablePolicyException=true"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--exceptionNamespace=platform-ns"}
]'
kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enablePolicyException=true"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--exceptionNamespace=platform-ns"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
]'
for d in kyverno-admission-controller kyverno-reports-controller; do
  kubectl -n kyverno rollout status "deployment/${d}" --timeout=180s
done

kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: batch-require-limits
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
              - batch-ns
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

echo "Playground ready: exceptions enabled for platform-ns, batch-ns guarded by an Enforce limits policy."
