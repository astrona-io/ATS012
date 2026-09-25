#!/usr/bin/env bash
# Confirms the Enforce policy is live and blocking, PolicyExceptions are
# enabled and scoped on both controllers, the exception waives the autogen
# rule too, the exempted workload is admitted, and the report shows skip.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

kubectl get clusterpolicy require-resource-limits >/dev/null 2>&1 \
  || fail_out "require-resource-limits - ClusterPolicy not found"

action=$(kubectl get clusterpolicy require-resource-limits -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
[[ "$action" == "Enforce" ]] \
  || fail_out "require-resource-limits - validationFailureAction is '$action', expected Enforce"

kubectl get clusterpolicy require-resource-limits -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw check-limits \
  || fail_out "require-resource-limits - no rule named 'check-limits'"

if kubectl get deployment new-api -n legacy-ns >/dev/null 2>&1; then
  fail_out "new-api exists in legacy-ns - the Enforce policy (via its autogen rule) should have blocked it"
fi

for d in kyverno-admission-controller kyverno-reports-controller; do
  args=$(kubectl get deployment "$d" -n kyverno -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null)
  [[ -n "$args" ]] || fail_out "$d - could not read container args"

  enabled=$(echo "$args" | tr ',' '\n' | grep -o 'enablePolicyException=[^"]*' | tail -1 | cut -d= -f2)
  [[ "$enabled" == "true" ]] \
    || fail_out "$d - effective --enablePolicyException is '${enabled:-unset}', expected true"

  exns=$(echo "$args" | tr ',' '\n' | grep -o 'exceptionNamespace=[^"]*' | tail -1 | cut -d= -f2)
  [[ "$exns" == "platform-ns" ]] \
    || fail_out "$d - effective --exceptionNamespace is '${exns:-unset}', expected platform-ns"
done

rargs=$(kubectl get deployment kyverno-reports-controller -n kyverno -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null)
interval=$(echo "$rargs" | tr ',' '\n' | grep -o 'backgroundScanInterval=[^"]*' | tail -1 | cut -d= -f2)
[[ "$interval" == "1m" ]] \
  || fail_out "kyverno-reports-controller - effective --backgroundScanInterval is '${interval:-unset}', expected 1m"

kubectl get policyexception allow-legacy-api -n platform-ns >/dev/null 2>&1 \
  || fail_out "allow-legacy-api - PolicyException not found in platform-ns"

pname=$(kubectl get policyexception allow-legacy-api -n platform-ns -o jsonpath='{.spec.exceptions[*].policyName}' 2>/dev/null)
echo "$pname" | grep -qw "require-resource-limits" \
  || fail_out "allow-legacy-api - spec.exceptions does not reference policyName 'require-resource-limits' (found: '${pname:-none}')"

rnames=$(kubectl get policyexception allow-legacy-api -n platform-ns -o jsonpath='{.spec.exceptions[*].ruleNames[*]}' 2>/dev/null)
echo "$rnames" | grep -qw "check-limits" \
  || fail_out "allow-legacy-api - ruleNames does not include 'check-limits' (found: '${rnames:-none}')"
if ! echo "$rnames" | grep -qE 'autogen-check-limits|\*'; then
  fail_out "allow-legacy-api - ruleNames does not include 'autogen-check-limits'; the Deployment is blocked by the autogen rule, not by check-limits"
fi

ready=$(kubectl get deployment legacy-api -n legacy-ns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$ready" && "$ready" -ge 1 ]] \
  || fail_out "legacy-api - Deployment is not ready in legacy-ns; a re-rolled Pod must be admitted through the exception"

gen=$(kubectl get deployment legacy-api -n legacy-ns -o jsonpath='{.metadata.generation}' 2>/dev/null)
[[ -n "$gen" && "$gen" -ge 2 ]] \
  || fail_out "legacy-api - the Deployment was never re-rolled (metadata.generation is ${gen:-unset}); patch its Pod template so a new Pod goes through admission"

found_skip=0
for _ in $(seq 1 45); do
  skips=$(kubectl get polr -n legacy-ns -o jsonpath='{range .items[*]}{range .results[?(@.result=="skip")]}{.properties.exceptions}{"\n"}{end}{end}' 2>/dev/null)
  if echo "$skips" | grep -qw "allow-legacy-api"; then
    found_skip=1
    break
  fi
  sleep 5
done
[[ "$found_skip" -eq 1 ]] \
  || fail_out "legacy-ns - no PolicyReport result with result=skip and properties.exceptions=allow-legacy-api; is --enablePolicyException=true set on the reports controller too?"

echo "PASS: Enforce policy blocked new-api, exceptions are enabled and scoped to platform-ns on both controllers, allow-legacy-api waives the autogen rule, legacy-api re-rolled successfully, and the report records the exemption as skip."
exit 0
