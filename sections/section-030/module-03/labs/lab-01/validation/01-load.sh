#!/usr/bin/env bash
# Three compliant Pods must be running in load-ns, and nothing without limits
# may have been admitted.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

count=0
for p in $(kubectl get pods -n load-ns -o name 2>/dev/null); do
  lim=$(kubectl get "$p" -n load-ns -o jsonpath='{.spec.containers[*].resources.limits.memory}' 2>/dev/null)
  if [[ -z "$lim" ]]; then
    fail_out "$p - a Pod in load-ns has no memory limit; the Enforce policy should have rejected it"
  fi
  count=$((count + 1))
done

[[ "$count" -ge 3 ]] || fail_out "load-ns - found $count Pods, expected at least 3 compliant Pods"

echo "PASS: $count compliant Pods run in load-ns and none lacks limits."
exit 0
