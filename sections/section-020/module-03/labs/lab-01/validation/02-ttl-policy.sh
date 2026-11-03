#!/usr/bin/env bash
# An Enforce policy must require the ttl label on every PolicyException, and an
# exception without it must have been rejected.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

kubectl get clusterpolicy require-exception-ttl >/dev/null 2>&1 || fail_out "require-exception-ttl - ClusterPolicy not found"
a=$(kubectl get clusterpolicy require-exception-ttl -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
[[ "$a" == "Enforce" ]] || fail_out "require-exception-ttl - validationFailureAction is '$a', expected Enforce"
b=$(kubectl get clusterpolicy require-exception-ttl -o jsonpath='{.spec.background}' 2>/dev/null)
[[ "$b" == "false" ]] || fail_out "require-exception-ttl - spec.background is '${b:-unset}', expected false"
kubectl get clusterpolicy require-exception-ttl -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw check-ttl \
  || fail_out "require-exception-ttl - no rule named 'check-ttl'"
kinds=$(kubectl get clusterpolicy require-exception-ttl -o jsonpath='{.spec.rules[*].match}' 2>/dev/null)
grep -q PolicyException <<<"$kinds" || fail_out "require-exception-ttl - its rule does not match PolicyException resources"
body=$(kubectl get clusterpolicy require-exception-ttl -o jsonpath='{.spec.rules[*].validate}' 2>/dev/null)
grep -q 'cleanup.kyverno.io/ttl' <<<"$body" || fail_out "require-exception-ttl - the validate block does not check the label cleanup.kyverno.io/ttl"

if kubectl get policyexception no-ttl -n platform-ns >/dev/null 2>&1; then
  fail_out "no-ttl exists in platform-ns - require-exception-ttl should have rejected an exception with no ttl label"
fi

echo "PASS: require-exception-ttl is an Enforce policy on PolicyException and no-ttl was rejected."
exit 0
