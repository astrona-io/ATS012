#!/usr/bin/env bash
# red-bad must be gone together with its report, and blue-bad must have results.

set -u

if kubectl get pod red-bad -n team-red >/dev/null 2>&1; then
  echo "FAIL: red-bad - the Pod still exists in team-red; delete it to see its report go with it"
  exit 1
fi

gone=""
for _ in $(seq 1 30); do
  names=$(kubectl get polr -n team-red -o jsonpath='{.items[*].scope.name}' 2>/dev/null)
  if ! grep -qw "red-bad" <<<"$names"; then gone=yes; break; fi
  sleep 4
done
if [[ -z "$gone" ]]; then
  echo "FAIL: red-bad - a PolicyReport for red-bad is still listed in team-red"
  exit 1
fi

fails=""
for _ in $(seq 1 40); do
  fails=$(kubectl get polr -n team-blue -o jsonpath='{range .items[*]}{.scope.name}{" "}{.summary.fail}{"\n"}{end}' 2>/dev/null | awk '$1=="blue-bad"{print $2}')
  if [[ -n "$fails" && "$fails" -ge 1 ]]; then break; fi
  sleep 4
done
if [[ -z "$fails" || "$fails" -lt 1 ]]; then
  echo "FAIL: blue-bad - no PolicyReport with at least one fail found in team-blue yet (are both policies applied and is background scanning running?)"
  exit 1
fi

echo "PASS: red-bad and its report are gone, and blue-bad's report records $fails fail result(s)."
exit 0
