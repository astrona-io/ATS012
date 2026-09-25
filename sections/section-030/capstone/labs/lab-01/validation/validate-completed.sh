#!/usr/bin/env bash
# Section 030 capstone: confirms the metrics configuration, identical
# enforcement in both namespaces, and an endpoint that attributes results to
# svc-a-ns while never mentioning ci-ns.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

METRICS_URL="http://kyverno-svc-metrics.kyverno.svc:8000/metrics"
scrape() { kubectl exec metrics-probe -n default -- curl -s --max-time 30 "$METRICS_URL" 2>/dev/null; }

# --- ConfigMap ------------------------------------------------------------
ns_key=$(kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.namespaces}' 2>/dev/null | tr -d ' ')
echo "$ns_key" | grep -q '"exclude":\["ci-ns"\]' \
  || fail_out "kyverno-metrics - namespaces is '${ns_key:-unset}', expected ci-ns in the exclude list"

expo=$(kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.metricsExposure}' 2>/dev/null | tr -d ' ')
echo "$expo" | grep -q '"kyverno_policy_results_total":{"disabledLabelDimensions":\[\]}' \
  || fail_out "kyverno-metrics - metricsExposure does not enable all label dimensions for kyverno_policy_results_total"
for kept in kyverno_admission_requests_total kyverno_policy_rule_info_total kyverno_policy_execution_duration_seconds; do
  echo "$expo" | grep -q "$kept" \
    || fail_out "kyverno-metrics - metricsExposure lost the shipped entry for $kept; keep every default entry and change only kyverno_policy_results_total"
done

buckets=$(kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.bucketBoundaries}' 2>/dev/null | tr -d ' ')
[[ "$buckets" == "0.02,0.2,2" ]] \
  || fail_out "kyverno-metrics - bucketBoundaries is '${buckets:-unset}', expected 0.02, 0.2, 2"

# --- policy ---------------------------------------------------------------
kubectl get clusterpolicy capstone-metrics-limits >/dev/null 2>&1 \
  || fail_out "capstone-metrics-limits - ClusterPolicy not found"
a=$(kubectl get clusterpolicy capstone-metrics-limits -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
[[ "$a" == "Enforce" ]] || fail_out "capstone-metrics-limits - validationFailureAction is '$a', expected Enforce"
mns=$(kubectl get clusterpolicy capstone-metrics-limits -o jsonpath='{.spec.rules[*].match.any[*].resources.namespaces[*]}' 2>/dev/null)
for n in svc-a-ns ci-ns; do
  echo "$mns" | grep -qw "$n" || fail_out "capstone-metrics-limits - rule does not match namespace '$n' (matched: '${mns:-none}')"
done

# --- enforcement outcomes -------------------------------------------------
kubectl get pod svc-a-ok -n svc-a-ns >/dev/null 2>&1 \
  || fail_out "svc-a-ok - Pod not found in svc-a-ns; a compliant Pod must be admitted"
lim=$(kubectl get pod svc-a-ok -n svc-a-ns -o jsonpath='{.spec.containers[0].resources.limits}' 2>/dev/null)
echo "$lim" | grep -q cpu || fail_out "svc-a-ok - no CPU limit on its container"
echo "$lim" | grep -q memory || fail_out "svc-a-ok - no memory limit on its container"

if kubectl get pod svc-a-bad -n svc-a-ns >/dev/null 2>&1; then
  fail_out "svc-a-bad exists in svc-a-ns - the Enforce policy should have rejected it"
fi
if kubectl get pod ci-bad -n ci-ns >/dev/null 2>&1; then
  fail_out "ci-bad exists in ci-ns - excluding a namespace from metrics must not weaken enforcement there"
fi

# --- endpoint -------------------------------------------------------------
metrics=""
for _ in $(seq 1 24); do
  metrics=$(scrape)
  if echo "$metrics" | grep '^kyverno_policy_results' | grep -q 'resource_namespace="svc-a-ns"'; then
    break
  fi
  sleep 5
done

echo "$metrics" | grep -q '^kyverno_' \
  || fail_out "could not scrape $METRICS_URL from metrics-probe"

echo "$metrics" | grep '^kyverno_policy_rule_info_total' | grep 'capstone-metrics-limits' | grep -q 'policy_validation_mode="enforce"' \
  || fail_out "kyverno_policy_rule_info_total has no enforce-mode series for capstone-metrics-limits"

svc_results=$(echo "$metrics" | grep '^kyverno_policy_results' | grep 'resource_namespace="svc-a-ns"')
[[ -n "$svc_results" ]] \
  || fail_out "kyverno_policy_results_total has no series with resource_namespace=\"svc-a-ns\"; did the admission controller restart after the ConfigMap change?"
echo "$svc_results" | grep -qi 'rule_result="pass"' \
  || fail_out "no rule_result=\"pass\" series for svc-a-ns; svc-a-ok should have produced one"
echo "$svc_results" | grep -qi 'rule_result="fail"' \
  || fail_out "no rule_result=\"fail\" series for svc-a-ns; the rejected svc-a-bad should have produced one"

if echo "$metrics" | grep -q 'ci-ns'; then
  fail_out "a metric series mentions ci-ns; the namespaces exclude list must keep it out of measurement entirely"
fi

denied=$(echo "$metrics" | grep '^kyverno_admission_requests_total' | grep 'request_allowed="false"' | head -1)
[[ -n "$denied" ]] \
  || fail_out "kyverno_admission_requests_total has no request_allowed=\"false\" series; the rejections were not counted"
dval=${denied##* }
[[ "${dval%%.*}" -ge 1 ]] \
  || fail_out "kyverno_admission_requests_total request_allowed=\"false\" is $dval, expected at least 1"

les=$(echo "$metrics" | grep '^kyverno_admission_review_duration_seconds_bucket' | grep -o 'le="[^"]*"' | sort -u)
[[ -n "$les" ]] || fail_out "kyverno_admission_review_duration_seconds_bucket is not present on the endpoint"
echo "$les" | grep -q 'le="0.02"' \
  || fail_out "kyverno_admission_review_duration_seconds_bucket has no le=\"0.02\" boundary; the custom bucketBoundaries are not in effect"
if echo "$les" | grep -q 'le="0.025"'; then
  fail_out "kyverno_admission_review_duration_seconds_bucket still carries the default le=\"0.025\"; restart the admission controller after changing bucketBoundaries"
fi

echo "PASS: metrics configured (ci-ns excluded, per-namespace attribution on, custom buckets), enforcement identical in both namespaces, and the endpoint attributes pass and fail to svc-a-ns while never mentioning ci-ns."
exit 0
