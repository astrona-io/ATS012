#!/usr/bin/env bash
# Confirms the kyverno-metrics ConfigMap changes are both configured and
# visible on the endpoint: per-namespace attribution on policy results,
# excluded-ns measured nowhere, and the custom histogram buckets in use.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

METRICS_URL="http://kyverno-svc-metrics.kyverno.svc:8000/metrics"
scrape() { kubectl exec metrics-probe -n default -- curl -s --max-time 30 "$METRICS_URL" 2>/dev/null; }

# --- ConfigMap ------------------------------------------------------------
ns_key=$(kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.namespaces}' 2>/dev/null | tr -d ' ')
[[ -n "$ns_key" ]] || fail_out "kyverno-metrics - could not read the 'namespaces' key"
echo "$ns_key" | grep -q '"exclude":\["excluded-ns"\]' \
  || fail_out "kyverno-metrics - namespaces is '$ns_key', expected excluded-ns in the exclude list"

expo=$(kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.metricsExposure}' 2>/dev/null | tr -d ' ')
[[ -n "$expo" ]] || fail_out "kyverno-metrics - could not read the 'metricsExposure' key"
echo "$expo" | grep -q '"kyverno_policy_results_total":{"disabledLabelDimensions":\[\]}' \
  || fail_out "kyverno-metrics - metricsExposure does not set an empty disabledLabelDimensions list for kyverno_policy_results_total"
for kept in kyverno_admission_requests_total kyverno_policy_rule_info_total; do
  echo "$expo" | grep -q "$kept" \
    || fail_out "kyverno-metrics - metricsExposure no longer contains an entry for $kept; keep every shipped entry and change only kyverno_policy_results_total"
done

buckets=$(kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.bucketBoundaries}' 2>/dev/null | tr -d ' ')
[[ "$buckets" == "0.01,0.1,1,5,10" ]] \
  || fail_out "kyverno-metrics - bucketBoundaries is '${buckets:-unset}', expected 0.01, 0.1, 1, 5, 10"

# --- policy and workloads -------------------------------------------------
kubectl get clusterpolicy metrics-config-limits >/dev/null 2>&1 \
  || fail_out "metrics-config-limits - ClusterPolicy not found"
a=$(kubectl get clusterpolicy metrics-config-limits -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
[[ "$a" == "Audit" ]] || fail_out "metrics-config-limits - validationFailureAction is '$a', expected Audit"
mns=$(kubectl get clusterpolicy metrics-config-limits -o jsonpath='{.spec.rules[*].match.any[*].resources.namespaces[*]}' 2>/dev/null)
for n in watched-ns excluded-ns; do
  echo "$mns" | grep -qw "$n" || fail_out "metrics-config-limits - rule does not match namespace '$n' (matched: '${mns:-none}')"
done

kubectl get pod watched-pod -n watched-ns >/dev/null 2>&1 \
  || fail_out "watched-pod - Pod not found in watched-ns"
kubectl get pod excluded-pod -n excluded-ns >/dev/null 2>&1 \
  || fail_out "excluded-pod - Pod not found in excluded-ns (the policy is Audit, so it must be admitted)"

# --- endpoint -------------------------------------------------------------
metrics=""
for _ in $(seq 1 24); do
  metrics=$(scrape)
  if echo "$metrics" | grep '^kyverno_policy_results' | grep -q 'resource_namespace="watched-ns"'; then
    break
  fi
  sleep 5
done

echo "$metrics" | grep -q '^kyverno_' \
  || fail_out "could not scrape $METRICS_URL from metrics-probe"

echo "$metrics" | grep '^kyverno_policy_results' | grep -q 'resource_namespace="watched-ns"' \
  || fail_out "kyverno_policy_results_total has no series with resource_namespace=\"watched-ns\"; did the admission controller restart after the ConfigMap change?"

if echo "$metrics" | grep -q 'excluded-ns'; then
  fail_out "a metric series mentions excluded-ns; the namespaces exclude list should keep it out of measurement entirely"
fi

bucket_les=$(echo "$metrics" | grep '^kyverno_admission_review_duration_seconds_bucket' | grep -o 'le="[^"]*"' | sort -u)
[[ -n "$bucket_les" ]] \
  || fail_out "kyverno_admission_review_duration_seconds_bucket is not present; generate some admission traffic and re-check"
echo "$bucket_les" | grep -q 'le="0.01"' \
  || fail_out "kyverno_admission_review_duration_seconds_bucket has no le=\"0.01\" boundary; the custom bucketBoundaries are not in effect"
if echo "$bucket_les" | grep -q 'le="0.025"'; then
  fail_out "kyverno_admission_review_duration_seconds_bucket still has the default le=\"0.025\" boundary; restart the admission controller so the new buckets are built"
fi

# reports still produced for the unmeasured namespace
polr=$(kubectl get polr -n excluded-ns -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$polr" -eq 0 ]]; then
  echo "NOTE: no PolicyReport in excluded-ns yet - background aggregation may still be in flight. Metrics exclusion does not affect reporting."
fi

echo "PASS: namespaces excludes excluded-ns, kyverno_policy_results_total carries resource_namespace attribution for watched-ns, no series mention excluded-ns, and the custom histogram boundaries are live."
exit 0
