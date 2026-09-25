#!/usr/bin/env bash
# Confirms the exception-hygiene policy rejects unannotated exceptions, and
# that the condition-gated exception exempts only workloads carrying the
# opt-in label - visible in the reports as a skip naming the exception.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

kubectl get clusterpolicy batch-require-limits >/dev/null 2>&1 \
  || fail_out "batch-require-limits - ClusterPolicy not found"
a=$(kubectl get clusterpolicy batch-require-limits -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
[[ "$a" == "Enforce" ]] || fail_out "batch-require-limits - validationFailureAction is '$a', expected Enforce"
kubectl get clusterpolicy batch-require-limits -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw check-limits \
  || fail_out "batch-require-limits - no rule named 'check-limits'"

kubectl get clusterpolicy require-exception-metadata >/dev/null 2>&1 \
  || fail_out "require-exception-metadata - ClusterPolicy not found"
ha=$(kubectl get clusterpolicy require-exception-metadata -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
[[ "$ha" == "Enforce" ]] || fail_out "require-exception-metadata - validationFailureAction is '$ha', expected Enforce"
hb=$(kubectl get clusterpolicy require-exception-metadata -o jsonpath='{.spec.background}' 2>/dev/null)
[[ "$hb" == "false" ]] || fail_out "require-exception-metadata - spec.background is '${hb:-unset}', expected false"
hk=$(kubectl get clusterpolicy require-exception-metadata -o jsonpath='{.spec.rules[*].match.any[*].resources.kinds[*]}' 2>/dev/null)
echo "$hk" | grep -qw PolicyException \
  || fail_out "require-exception-metadata - its rule does not match PolicyException resources (matched kinds: '${hk:-none}')"

if kubectl get policyexception sloppy-exception -n platform-ns >/dev/null 2>&1; then
  fail_out "sloppy-exception exists in platform-ns - require-exception-metadata should have rejected an exception with no owner/expires annotations"
fi

kubectl get policyexception allow-optin-batch -n platform-ns >/dev/null 2>&1 \
  || fail_out "allow-optin-batch - PolicyException not found in platform-ns"

for ann in owner expires; do
  v=$(kubectl get policyexception allow-optin-batch -n platform-ns -o jsonpath="{.metadata.annotations.exception\.company\.io/${ann}}" 2>/dev/null)
  [[ -n "$v" ]] || fail_out "allow-optin-batch - annotation exception.company.io/${ann} is missing or empty"
done

pn=$(kubectl get policyexception allow-optin-batch -n platform-ns -o jsonpath='{.spec.exceptions[*].policyName}' 2>/dev/null)
echo "$pn" | grep -qw batch-require-limits \
  || fail_out "allow-optin-batch - spec.exceptions does not reference policyName 'batch-require-limits' (found: '${pn:-none}')"

conds=$(kubectl get policyexception allow-optin-batch -n platform-ns -o json 2>/dev/null | tr -d ' \n')
echo "$conds" | grep -q '"conditions"' \
  || fail_out "allow-optin-batch - no conditions block; the exemption must be gated on the opt-in label, not on names alone"
echo "$conds" | grep -q 'labels.exempt' \
  || fail_out "allow-optin-batch - the conditions block does not reference the 'exempt' label"

if kubectl get pod no-optin -n batch-ns >/dev/null 2>&1; then
  fail_out "no-optin exists in batch-ns - without the 'exempt' label the exception must not apply and the Enforce policy must block it"
fi

kubectl get pod with-optin -n batch-ns >/dev/null 2>&1 \
  || fail_out "with-optin - Pod not found in batch-ns; with the 'exempt: \"true\"' label the exception should admit it"

lbl=$(kubectl get pod with-optin -n batch-ns -o jsonpath='{.metadata.labels.exempt}' 2>/dev/null)
[[ "$lbl" == "true" ]] \
  || fail_out "with-optin - label 'exempt' is '${lbl:-unset}', expected \"true\""

limits=$(kubectl get pod with-optin -n batch-ns -o jsonpath='{.spec.containers[0].resources.limits}' 2>/dev/null)
[[ -z "$limits" ]] \
  || fail_out "with-optin - the container sets resource limits ($limits); it must violate the policy so that the exception is what admits it"

uid=$(kubectl get pod with-optin -n batch-ns -o jsonpath='{.metadata.uid}' 2>/dev/null)
found=0
for _ in $(seq 1 40); do
  if kubectl get polr "$uid" -n batch-ns -o jsonpath='{range .results[?(@.result=="skip")]}{.properties.exceptions}{"\n"}{end}' 2>/dev/null | grep -qw allow-optin-batch; then
    found=1
    break
  fi
  sleep 5
done
[[ "$found" -eq 1 ]] \
  || fail_out "with-optin - no report result with result=skip and properties.exceptions=allow-optin-batch"

echo "PASS: the hygiene policy rejected an unannotated exception, allow-optin-batch is condition-gated on the 'exempt' label, no-optin stayed blocked, with-optin was admitted, and the report records the exemption as skip."
exit 0
