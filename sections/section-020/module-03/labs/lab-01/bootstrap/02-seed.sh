#!/usr/bin/env bash
set -eu

for ns in batch-ns platform-ns; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# Module 1 already covered turning the feature on; this lab is about giving an
# exception an end date, so the flags are pre-set here.
for d in kyverno-admission-controller kyverno-reports-controller; do
  kubectl -n kyverno patch deployment "$d" --type=json -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enablePolicyException=true"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--exceptionNamespace=platform-ns"}
  ]'
done

for d in kyverno-admission-controller kyverno-reports-controller; do
  kubectl -n kyverno rollout status "deployment/${d}" --timeout=180s
done

kubectl apply -f - <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: batch-require-limits
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
YAML

echo "batch-ns and platform-ns ready; exceptions enabled for platform-ns; batch-require-limits is live in Enforce mode."
