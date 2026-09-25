#!/usr/bin/env bash
# Confirms both Audit policies are live (one scored, one advisory), that the
# violating Pod was admitted and recorded with a fail and a warn, and that the
# compliant Pod recorded neither.

set -u

NS="platform-ns"

policy_json=$(kubectl get clusterpolicy require-resource-limits -o json 2>/dev/null)
if [[ -z "$policy_json" ]]; then
  echo "FAIL: require-resource-limits - ClusterPolicy not found"
  exit 1
fi

action=$(kubectl get clusterpolicy require-resource-limits -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
if [[ "$action" != "Audit" ]]; then
  echo "FAIL: require-resource-limits - validationFailureAction is '$action', expected Audit"
  exit 1
fi

if ! kubectl get clusterpolicy require-resource-limits -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw "check-limits"; then
  echo "FAIL: require-resource-limits - no rule named 'check-limits' found"
  exit 1
fi

if ! kubectl get clusterpolicy require-team-label >/dev/null 2>&1; then
  echo "FAIL: require-team-label - ClusterPolicy not found"
  exit 1
fi

advisory_action=$(kubectl get clusterpolicy require-team-label -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
if [[ "$advisory_action" != "Audit" ]]; then
  echo "FAIL: require-team-label - validationFailureAction is '$advisory_action', expected Audit"
  exit 1
fi

scored=$(kubectl get clusterpolicy require-team-label -o jsonpath='{.metadata.annotations.policies\.kyverno\.io/scored}' 2>/dev/null)
if [[ "$scored" != "false" ]]; then
  echo "FAIL: require-team-label - annotation policies.kyverno.io/scored is '$scored', expected \"false\""
  exit 1
fi

if ! kubectl get clusterpolicy require-team-label -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw "check-team-label"; then
  echo "FAIL: require-team-label - no rule named 'check-team-label' found"
  exit 1
fi

for pod in compliant-pod violator-pod; do
  if ! kubectl get pod "$pod" -n "$NS" >/dev/null 2>&1; then
    echo "FAIL: $pod - Pod not found in $NS (violator-pod must be admitted: both policies are Audit)"
    exit 1
  fi
done

vuid=$(kubectl get pod violator-pod -n "$NS" -o jsonpath='{.metadata.uid}' 2>/dev/null)
if [[ -z "$vuid" ]]; then
  echo "FAIL: violator-pod - could not read metadata.uid"
  exit 1
fi

fail_count=""
warn_count=""
for _ in $(seq 1 30); do
  fail_count=$(kubectl get polr "$vuid" -n "$NS" -o jsonpath='{.summary.fail}' 2>/dev/null)
  warn_count=$(kubectl get polr "$vuid" -n "$NS" -o jsonpath='{.summary.warn}' 2>/dev/null)
  if [[ -n "$fail_count" && -n "$warn_count" && "$fail_count" -ge 1 && "$warn_count" -ge 1 ]]; then
    break
  fi
  sleep 4
done

if [[ -z "${fail_count:-}" ]]; then
  echo "FAIL: violator-pod - no PolicyReport named after the Pod's UID ($vuid) found in $NS"
  exit 1
fi

if [[ "$fail_count" -lt 1 ]]; then
  echo "FAIL: violator-pod - PolicyReport summary.fail is $fail_count, expected at least 1 from require-resource-limits"
  exit 1
fi

if [[ "${warn_count:-0}" -lt 1 ]]; then
  echo "FAIL: violator-pod - PolicyReport summary.warn is ${warn_count:-0}, expected at least 1 from the advisory require-team-label policy (is policies.kyverno.io/scored set to \"false\"?)"
  exit 1
fi

cuid=$(kubectl get pod compliant-pod -n "$NS" -o jsonpath='{.metadata.uid}' 2>/dev/null)
cfail=$(kubectl get polr "$cuid" -n "$NS" -o jsonpath='{.summary.fail}' 2>/dev/null)
cwarn=$(kubectl get polr "$cuid" -n "$NS" -o jsonpath='{.summary.warn}' 2>/dev/null)
if [[ -n "$cfail" && "$cfail" -gt 0 ]]; then
  echo "FAIL: compliant-pod - PolicyReport summary.fail is $cfail, expected 0 (the Pod must satisfy require-resource-limits)"
  exit 1
fi
if [[ -n "$cwarn" && "$cwarn" -gt 0 ]]; then
  echo "FAIL: compliant-pod - PolicyReport summary.warn is $cwarn, expected 0 (the Pod must carry a 'team' label)"
  exit 1
fi

echo "PASS: both Audit policies are live, violator-pod was admitted and recorded ${fail_count} fail / ${warn_count} warn, and compliant-pod recorded neither."
exit 0
