#!/usr/bin/env bash
# The learner records what the endpoint shows. Counters only grow, so a value
# written earlier must be at least what the task generated and at most what the
# endpoint reports now.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

METRICS_URL="http://kyverno-svc-metrics.kyverno.svc:8000/metrics"
scrape() { kubectl exec metrics-probe -n default -- curl -s --max-time 30 "$METRICS_URL" 2>/dev/null; }

kubectl get configmap metrics-findings -n load-ns >/dev/null 2>&1 \
  || fail_out "metrics-findings - ConfigMap not found in load-ns"

get() { kubectl get configmap metrics-findings -n load-ns -o jsonpath="{.data.$1}" 2>/dev/null | tr -d ' \n'; }
pass=$(get pass-total)
fail=$(get fail-total)
reviews=$(get admission-review-count)

for pair in "pass-total:$pass" "fail-total:$fail" "admission-review-count:$reviews"; do
  k=${pair%%:*}; v=${pair#*:}
  [[ -n "$v" ]] || fail_out "metrics-findings - key '$k' is missing or empty"
  [[ "$v" =~ ^[0-9]+$ ]] || fail_out "metrics-findings - key '$k' is '$v', expected a whole number"
done

metrics=$(scrape)
echo "$metrics" | grep -q '^kyverno_' || fail_out "could not scrape $METRICS_URL from metrics-probe"

# Sum the value column of the matching lines, rounding down to a whole number.
sum_lines() { awk '{s += $NF} END {printf "%d", s}'; }

live_pass=$(echo "$metrics" | grep '^kyverno_policy_results_total' | grep 'policy_name="load-require-limits"' | grep 'rule_result="pass"' | grep 'rule_execution_cause="admission_request"' | sum_lines)
live_fail=$(echo "$metrics" | grep '^kyverno_policy_results_total' | grep 'policy_name="load-require-limits"' | grep 'rule_result="fail"' | grep 'rule_execution_cause="admission_request"' | sum_lines)
live_reviews=$(echo "$metrics" | grep '^kyverno_admission_review_duration_seconds_count' | sum_lines)

[[ "$pass" -ge 3 ]] || fail_out "pass-total is $pass; the three compliant Pods should have produced at least 3 admission passes"
[[ "$pass" -le "$live_pass" ]] || fail_out "pass-total is $pass but the endpoint reports only $live_pass admission passes for load-require-limits"
[[ "$fail" -ge 2 ]] || fail_out "fail-total is $fail; the two rejected Pods should have produced at least 2 admission failures"
[[ "$fail" -le "$live_fail" ]] || fail_out "fail-total is $fail but the endpoint reports only $live_fail admission failures for load-require-limits"
[[ "$reviews" -ge 5 ]] || fail_out "admission-review-count is $reviews; five Pod requests were made, so at least 5 admission reviews were counted"
[[ "$reviews" -le "$live_reviews" ]] || fail_out "admission-review-count is $reviews but the endpoint reports $live_reviews admission reviews"

echo "PASS: recorded pass-total=$pass, fail-total=$fail and admission-review-count=$reviews agree with the endpoint."
exit 0
