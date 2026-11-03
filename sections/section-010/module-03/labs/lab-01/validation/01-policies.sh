#!/usr/bin/env bash
# Both Audit policies must exist with the right rule, namespaces, severity and category.

set -u

check_policy() {
  local name="$1" rule="$2" sev="$3" cat="$4"
  if ! kubectl get clusterpolicy "$name" >/dev/null 2>&1; then
    echo "FAIL: $name - ClusterPolicy not found"; exit 1
  fi
  local action; action=$(kubectl get clusterpolicy "$name" -o jsonpath='{.spec.validationFailureAction}')
  if [[ "$action" != "Audit" ]]; then
    echo "FAIL: $name - validationFailureAction is '$action', expected Audit"; exit 1
  fi
  if ! kubectl get clusterpolicy "$name" -o jsonpath='{.spec.rules[*].name}' | grep -qw "$rule"; then
    echo "FAIL: $name - no rule named '$rule'"; exit 1
  fi
  local s c
  s=$(kubectl get clusterpolicy "$name" -o jsonpath='{.metadata.annotations.policies\.kyverno\.io/severity}')
  c=$(kubectl get clusterpolicy "$name" -o jsonpath='{.metadata.annotations.policies\.kyverno\.io/category}')
  if [[ "$s" != "$sev" ]]; then
    echo "FAIL: $name - annotation policies.kyverno.io/severity is '$s', expected '$sev'"; exit 1
  fi
  if [[ "$c" != "$cat" ]]; then
    echo "FAIL: $name - annotation policies.kyverno.io/category is '$c', expected '$cat'"; exit 1
  fi
  local ns; ns=$(kubectl get clusterpolicy "$name" -o jsonpath='{.spec.rules[*].match}')
  for want in team-red team-blue; do
    if ! grep -qw "$want" <<<"$ns"; then
      echo "FAIL: $name - the match block does not list namespace $want"; exit 1
    fi
  done
}

check_policy require-resource-limits check-limits high "Best Practices"
check_policy require-team-label check-team medium Governance

echo "PASS: both Audit policies exist with the expected rules, namespaces, severity and category."
exit 0
