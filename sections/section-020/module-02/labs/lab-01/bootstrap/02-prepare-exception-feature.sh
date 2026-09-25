#!/usr/bin/env bash
set -eu

for ns in batch-ns platform-ns; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# Module 1 already covered turning the feature on; this lab is about narrowing
# and governing exceptions, so the flags are pre-set here.
for d in kyverno-admission-controller kyverno-reports-controller; do
  kubectl -n kyverno patch deployment "$d" --type=json -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enablePolicyException=true"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--exceptionNamespace=platform-ns"}
  ]'
done

kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
]'

for d in kyverno-admission-controller kyverno-reports-controller; do
  kubectl -n kyverno rollout status "deployment/${d}" --timeout=180s
done

echo "batch-ns and platform-ns ready; PolicyExceptions enabled and scoped to platform-ns on the admission and reports controllers."
