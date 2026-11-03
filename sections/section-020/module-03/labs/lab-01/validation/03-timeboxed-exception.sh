#!/usr/bin/env bash
# The time-boxed exception must carry the ttl and owner, waive the limits rule
# (and its autogen counterpart) and exempt grace-pod but not strict-pod.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

kubectl get policyexception allow-batch-timeboxed -n platform-ns >/dev/null 2>&1 \
  || fail_out "allow-batch-timeboxed - PolicyException not found in platform-ns"

ttl=$(kubectl get policyexception allow-batch-timeboxed -n platform-ns -o jsonpath='{.metadata.labels.cleanup\.kyverno\.io/ttl}' 2>/dev/null)
[[ "$ttl" == "8h" ]] || fail_out "allow-batch-timeboxed - label cleanup.kyverno.io/ttl is '${ttl:-unset}', expected 8h"

owner=$(kubectl get policyexception allow-batch-timeboxed -n platform-ns -o jsonpath='{.metadata.annotations.exception\.company\.io/owner}' 2>/dev/null)
[[ -n "$owner" ]] || fail_out "allow-batch-timeboxed - annotation exception.company.io/owner is missing or empty"

pn=$(kubectl get policyexception allow-batch-timeboxed -n platform-ns -o jsonpath='{.spec.exceptions[*].policyName}' 2>/dev/null)
grep -qw batch-require-limits <<<"$pn" || fail_out "allow-batch-timeboxed - spec.exceptions does not reference policyName 'batch-require-limits'"
rn=$(kubectl get policyexception allow-batch-timeboxed -n platform-ns -o jsonpath='{.spec.exceptions[*].ruleNames[*]}' 2>/dev/null)
grep -qw check-limits <<<"$rn" || fail_out "allow-batch-timeboxed - ruleNames does not list check-limits"
grep -qw autogen-check-limits <<<"$rn" || fail_out "allow-batch-timeboxed - ruleNames does not list autogen-check-limits"

kubectl get pod grace-pod -n batch-ns >/dev/null 2>&1 \
  || fail_out "grace-pod - Pod not found in batch-ns; the exception should let a Pod without limits through"
lim=$(kubectl get pod grace-pod -n batch-ns -o jsonpath='{.spec.containers[*].resources.limits}' 2>/dev/null)
[[ -z "$lim" ]] || fail_out "grace-pod - sets resource limits, so it does not prove the exception works; create it without limits"

if kubectl get pod strict-pod -n batch-ns >/dev/null 2>&1; then
  fail_out "strict-pod exists in batch-ns - a Pod with no limits and a name outside the exception must be blocked"
fi

echo "PASS: allow-batch-timeboxed carries ttl 8h and an owner, waives only check-limits and its autogen rule, grace-pod was admitted and strict-pod stays blocked."
exit 0
