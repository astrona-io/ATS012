#!/usr/bin/env bash
# The cleanup controller must be allowed to delete PolicyExceptions, through a
# ClusterRole that carries the aggregation label.

set -u

SA="system:serviceaccount:kyverno:kyverno-cleanup-controller"

labelled=$(kubectl get clusterrole -l rbac.kyverno.io/aggregate-to-cleanup-controller=true -o name 2>/dev/null | grep -v 'kyverno:' || true)
if [[ -z "$labelled" ]]; then
  echo "FAIL: no ClusterRole of yours carries the label rbac.kyverno.io/aggregate-to-cleanup-controller=true"
  exit 1
fi

ok=""
for _ in $(seq 1 20); do
  out=$(kubectl auth can-i delete policyexceptions.kyverno.io -n platform-ns --as="$SA" 2>/dev/null)
  if [[ "$out" == "yes" ]]; then ok=yes; break; fi
  sleep 3
done
if [[ -z "$ok" ]]; then
  echo "FAIL: the cleanup controller ($SA) is still not allowed to delete policyexceptions; the ClusterRole must allow get, list, watch and delete on policyexceptions in the kyverno.io group"
  exit 1
fi

for verb in get list watch; do
  out=$(kubectl auth can-i "$verb" policyexceptions.kyverno.io -n platform-ns --as="$SA" 2>/dev/null)
  if [[ "$out" != "yes" ]]; then
    echo "FAIL: the cleanup controller may not '$verb' policyexceptions; the ttl handler needs get, list, watch and delete"
    exit 1
  fi
done

echo "PASS: the cleanup controller may get, list, watch and delete PolicyExceptions."
exit 0
