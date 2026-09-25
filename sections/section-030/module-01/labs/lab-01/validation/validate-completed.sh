#!/usr/bin/env bash
# Confirms the Enforce policy admitted the compliant Pod and rejected the
# violator, and that the metrics endpoint shows the policy inventory plus a
# pass and a fail result for it.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

METRICS_URL="http://kyverno-svc-metrics.kyverno.svc:8000/metrics"

scrape() {
  kubectl exec metrics-probe -n default -- curl -s --max-time 30 "$METRICS_URL" 2>/dev/null
}

kubectl get clusterpolicy metrics-demo-limits >/dev/null 2>&1 \
  || fail_out "metrics-demo-limits - ClusterPolicy not found"
a=$(kubectl get clusterpolicy metrics-demo-limits -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
[[ "$a" == "Enforce" ]] || fail_out "metrics-demo-limits - validationFailureAction is '$a', expected Enforce"
kubectl get clusterpolicy metrics-demo-limits -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw check-limits \
  || fail_out "metrics-demo-limits - no rule named 'check-limits'"

kubectl get pod metrics-pass-pod -n metrics-ns >/dev/null 2>&1 \
  || fail_out "metrics-pass-pod - Pod not found in metrics-ns; a Pod with CPU and memory limits must be admitted"

limits=$(kubectl get pod metrics-pass-pod -n metrics-ns -o jsonpath='{.spec.containers[0].resources.limits}' 2>/dev/null)
echo "$limits" | grep -q cpu || fail_out "metrics-pass-pod - no CPU limit set on its container"
echo "$limits" | grep -q memory || fail_out "metrics-pass-pod - no memory limit set on its container"

if kubectl get pod metrics-fail-pod -n metrics-ns >/dev/null 2>&1; then
  fail_out "metrics-fail-pod exists in metrics-ns - the Enforce policy should have rejected it"
fi

kubectl get pod metrics-probe -n default >/dev/null 2>&1 \
  || fail_out "metrics-probe - the probe Pod is missing from the default namespace; it is needed to scrape the metrics endpoint"

metrics=""
for _ in $(seq 1 20); do
  metrics=$(scrape)
  if echo "$metrics" | grep -q '^kyverno_'; then
    break
  fi
  sleep 5
done

echo "$metrics" | grep -q '^kyverno_' \
  || fail_out "could not scrape $METRICS_URL from metrics-probe - is the endpoint reachable and --disableMetrics still false?"

echo "$metrics" | grep '^kyverno_policy_rule_info_total' | grep -q 'policy_name="metrics-demo-limits"' \
  || fail_out "kyverno_policy_rule_info_total has no series with policy_name=\"metrics-demo-limits\""

results=$(echo "$metrics" | grep '^kyverno_policy_results' | grep 'policy_name="metrics-demo-limits"')
[[ -n "$results" ]] \
  || fail_out "kyverno_policy_results_total has no series for policy_name=\"metrics-demo-limits\""

pass_line=$(echo "$results" | grep -i 'rule_result="pass"' | head -1)
[[ -n "$pass_line" ]] \
  || fail_out "kyverno_policy_results_total has no rule_result=\"pass\" series for metrics-demo-limits; was a compliant Pod admitted?"
pass_val=${pass_line##* }
[[ "${pass_val%%.*}" -ge 1 ]] \
  || fail_out "kyverno_policy_results_total pass series is $pass_val, expected at least 1"

fail_line=$(echo "$results" | grep -i 'rule_result="fail"' | head -1)
[[ -n "$fail_line" ]] \
  || fail_out "kyverno_policy_results_total has no rule_result=\"fail\" series for metrics-demo-limits; was a violating Pod actually rejected?"
fail_val=${fail_line##* }
[[ "${fail_val%%.*}" -ge 1 ]] \
  || fail_out "kyverno_policy_results_total fail series is $fail_val, expected at least 1"

adm_line=$(echo "$metrics" | grep '^kyverno_admission_requests_total' | head -1)
[[ -n "$adm_line" ]] || fail_out "kyverno_admission_requests_total is not present on the endpoint"
adm_val=${adm_line##* }
[[ "${adm_val%%.*}" -ge 1 ]] \
  || fail_out "kyverno_admission_requests_total is $adm_val, expected a non-zero count"

echo "PASS: the metrics endpoint is reachable, metrics-demo-limits appears in kyverno_policy_rule_info_total, and kyverno_policy_results_total carries both a pass and a fail series for it."
exit 0
