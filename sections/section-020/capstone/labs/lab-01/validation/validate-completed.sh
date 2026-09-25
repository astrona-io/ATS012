#!/usr/bin/env bash
# Section 020 capstone: confirms the scoped feature flags, the enforcement and
# hygiene policies, one working auditable exemption, and one exception outside
# the exception namespace that provably has no effect.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

for d in kyverno-admission-controller kyverno-reports-controller; do
  args=$(kubectl get deployment "$d" -n kyverno -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null)
  [[ -n "$args" ]] || fail_out "$d - could not read container args"
  en=$(echo "$args" | tr ',' '\n' | grep -o 'enablePolicyException=[^"]*' | tail -1 | cut -d= -f2)
  [[ "$en" == "true" ]] || fail_out "$d - effective --enablePolicyException is '${en:-unset}', expected true"
  ns=$(echo "$args" | tr ',' '\n' | grep -o 'exceptionNamespace=[^"]*' | tail -1 | cut -d= -f2)
  [[ "$ns" == "platform-ns" ]] || fail_out "$d - effective --exceptionNamespace is '${ns:-unset}', expected platform-ns"
done

rargs=$(kubectl get deployment kyverno-reports-controller -n kyverno -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null)
iv=$(echo "$rargs" | tr ',' '\n' | grep -o 'backgroundScanInterval=[^"]*' | tail -1 | cut -d= -f2)
[[ "$iv" == "1m" ]] || fail_out "kyverno-reports-controller - effective --backgroundScanInterval is '${iv:-unset}', expected 1m"

kubectl get clusterpolicy prod-require-limits >/dev/null 2>&1 || fail_out "prod-require-limits - ClusterPolicy not found"
a=$(kubectl get clusterpolicy prod-require-limits -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
[[ "$a" == "Enforce" ]] || fail_out "prod-require-limits - validationFailureAction is '$a', expected Enforce"
kubectl get clusterpolicy prod-require-limits -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw check-limits \
  || fail_out "prod-require-limits - no rule named 'check-limits'"

kubectl get clusterpolicy require-exception-metadata >/dev/null 2>&1 || fail_out "require-exception-metadata - ClusterPolicy not found"
hb=$(kubectl get clusterpolicy require-exception-metadata -o jsonpath='{.spec.background}' 2>/dev/null)
[[ "$hb" == "false" ]] || fail_out "require-exception-metadata - spec.background is '${hb:-unset}', expected false"
hk=$(kubectl get clusterpolicy require-exception-metadata -o jsonpath='{.spec.rules[*].match.any[*].resources.kinds[*]}' 2>/dev/null)
echo "$hk" | grep -qw PolicyException \
  || fail_out "require-exception-metadata - its rule does not match PolicyException resources (matched kinds: '${hk:-none}')"

kubectl get policyexception allow-payments-api -n platform-ns >/dev/null 2>&1 \
  || fail_out "allow-payments-api - PolicyException not found in platform-ns"
for ann in owner expires; do
  v=$(kubectl get policyexception allow-payments-api -n platform-ns -o jsonpath="{.metadata.annotations.exception\.company\.io/${ann}}" 2>/dev/null)
  [[ -n "$v" ]] || fail_out "allow-payments-api - annotation exception.company.io/${ann} is missing or empty"
done
rn=$(kubectl get policyexception allow-payments-api -n platform-ns -o jsonpath='{.spec.exceptions[*].ruleNames[*]}' 2>/dev/null)
echo "$rn" | grep -qw check-limits || fail_out "allow-payments-api - ruleNames does not include 'check-limits'"
echo "$rn" | grep -qE 'autogen-check-limits|\*' \
  || fail_out "allow-payments-api - ruleNames does not include 'autogen-check-limits'"

ready=$(kubectl get deployment payments-api -n prod-ns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$ready" && "$ready" -ge 1 ]] \
  || fail_out "payments-api - Deployment is not ready in prod-ns; the exempted workload must be admitted"
gen=$(kubectl get deployment payments-api -n prod-ns -o jsonpath='{.metadata.generation}' 2>/dev/null)
[[ -n "$gen" && "$gen" -ge 2 ]] \
  || fail_out "payments-api - the Deployment was never re-rolled (metadata.generation is ${gen:-unset})"

kubectl get policyexception rogue-exception -n rogue-ns >/dev/null 2>&1 \
  || fail_out "rogue-exception - PolicyException not found in rogue-ns; it must exist to prove --exceptionNamespace scoping"

if kubectl get pod rogue-pod -n prod-ns >/dev/null 2>&1; then
  fail_out "rogue-pod exists in prod-ns - rogue-exception lives outside --exceptionNamespace and must be ignored, so the Pod should have been blocked"
fi

found=0
for _ in $(seq 1 45); do
  if kubectl get polr -n prod-ns -o jsonpath='{range .items[*]}{range .results[?(@.result=="skip")]}{.properties.exceptions}{"\n"}{end}{end}' 2>/dev/null | grep -qw allow-payments-api; then
    found=1
    break
  fi
  sleep 5
done
[[ "$found" -eq 1 ]] \
  || fail_out "prod-ns - no report result with result=skip and properties.exceptions=allow-payments-api"

if kubectl get polr -A -o jsonpath='{range .items[*]}{range .results[*]}{.properties.exceptions}{"\n"}{end}{end}' 2>/dev/null | grep -qw rogue-exception; then
  fail_out "a PolicyReport result names rogue-exception - an exception outside --exceptionNamespace must never take effect"
fi

echo "PASS: exceptions enabled and scoped to platform-ns, hygiene policy in force, payments-api exempted and auditable as skip, and rogue-exception had no effect on enforcement or reporting."
exit 0
