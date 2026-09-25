#!/usr/bin/env bash
# Confirms the reports pipeline was tuned (interval lowered, resourceFilters
# honoured), the pre-existing legacy-ns workload is reported and untouched,
# and quiet-ns produces no reports at all.

set -u

policy_json=$(kubectl get clusterpolicy audit-resource-limits -o json 2>/dev/null)
if [[ -z "$policy_json" ]]; then
  echo "FAIL: audit-resource-limits - ClusterPolicy not found"
  exit 1
fi

action=$(kubectl get clusterpolicy audit-resource-limits -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
if [[ "$action" != "Audit" ]]; then
  echo "FAIL: audit-resource-limits - validationFailureAction is '$action', expected Audit"
  exit 1
fi

if ! kubectl get clusterpolicy audit-resource-limits -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw "check-limits"; then
  echo "FAIL: audit-resource-limits - no rule named 'check-limits' found"
  exit 1
fi

matched_ns=$(kubectl get clusterpolicy audit-resource-limits -o jsonpath='{.spec.rules[*].match.any[*].resources.namespaces[*]}' 2>/dev/null)
for ns in legacy-ns quiet-ns; do
  if ! echo "$matched_ns" | grep -qw "$ns"; then
    echo "FAIL: audit-resource-limits - rule does not match namespace '$ns' (matched: '$matched_ns')"
    exit 1
  fi
done

args=$(kubectl get deployment kyverno-reports-controller -n kyverno -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null)
if [[ -z "$args" ]]; then
  echo "FAIL: kyverno-reports-controller - could not read container args"
  exit 1
fi

interval=$(echo "$args" | tr ',' '\n' | grep -o 'backgroundScanInterval=[^"]*' | tail -1 | cut -d= -f2)
if [[ "$interval" != "1m" ]]; then
  echo "FAIL: kyverno-reports-controller - effective --backgroundScanInterval is '${interval:-unset}', expected 1m"
  exit 1
fi

skip=$(echo "$args" | tr ',' '\n' | grep -o 'skipResourceFilters=[^"]*' | tail -1 | cut -d= -f2)
if [[ "$skip" != "false" ]]; then
  echo "FAIL: kyverno-reports-controller - effective --skipResourceFilters is '${skip:-unset}', expected false so that resourceFilters applies to background scans"
  exit 1
fi

filters=$(kubectl get configmap kyverno -n kyverno -o jsonpath='{.data.resourceFilters}' 2>/dev/null)
if ! echo "$filters" | grep -q '\[\*/\*,quiet-ns,\*\]'; then
  echo "FAIL: kyverno ConfigMap - resourceFilters does not contain [*/*,quiet-ns,*]"
  exit 1
fi
for keep in 'kube-system' 'Event' 'kyverno'; do
  if ! echo "$filters" | grep -q "$keep"; then
    echo "FAIL: kyverno ConfigMap - the default resourceFilters entry mentioning '$keep' was removed; keep the shipped defaults and append to them"
    exit 1
  fi
done

if ! kubectl get deployment legacy-api -n legacy-ns >/dev/null 2>&1; then
  echo "FAIL: legacy-api - Deployment missing from legacy-ns; background scanning must never delete a workload"
  exit 1
fi
ready=$(kubectl get deployment legacy-api -n legacy-ns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$ready" || "$ready" -lt 1 ]]; then
  echo "FAIL: legacy-api - Deployment is not ready in legacy-ns; it should have been reported on, not disturbed"
  exit 1
fi

found_fail=0
for _ in $(seq 1 45); do
  fails=$(kubectl get polr -n legacy-ns -o jsonpath='{range .items[*]}{.summary.fail}{"\n"}{end}' 2>/dev/null)
  for f in $fails; do
    if [[ "$f" -ge 1 ]]; then
      found_fail=1
      break
    fi
  done
  [[ "$found_fail" -eq 1 ]] && break
  sleep 5
done

if [[ "$found_fail" -ne 1 ]]; then
  echo "FAIL: legacy-ns - no PolicyReport with a failing result appeared; the background scan has not reported the pre-existing legacy-api workload"
  exit 1
fi

quiet_reports=$(kubectl get polr -n quiet-ns -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$quiet_reports" -ne 0 ]]; then
  echo "FAIL: quiet-ns - found $quiet_reports PolicyReport object(s); with [*/*,quiet-ns,*] filtered and --skipResourceFilters=false there should be none"
  exit 1
fi

echo "PASS: background scan interval is 1m, resourceFilters is honoured by the reports controller, legacy-api is reported and untouched, and quiet-ns produced no reports."
exit 0
