#!/usr/bin/env bash
# The alert rule is stored as text in a ConfigMap, because the Prometheus
# Operator is not installed in the lab cluster. Check what a reviewer would.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

kubectl get configmap kyverno-alert-rule -n load-ns >/dev/null 2>&1 \
  || fail_out "kyverno-alert-rule - ConfigMap not found in load-ns"

rule=$(kubectl get configmap kyverno-alert-rule -n load-ns -o jsonpath='{.data.rule\.yaml}' 2>/dev/null)
[[ -n "$rule" ]] || fail_out "kyverno-alert-rule - key 'rule.yaml' is missing or empty"

grep -q 'kind: *PrometheusRule' <<<"$rule" || fail_out "rule.yaml - kind is not PrometheusRule"
grep -q 'alert: *KyvernoPolicyViolations' <<<"$rule" || fail_out "rule.yaml - no 'alert: KyvernoPolicyViolations'"

expr=$(grep -E '^[[:space:]]*expr:' <<<"$rule" | head -n 1)
[[ -n "$expr" ]] || fail_out "rule.yaml - no 'expr:' line"
grep -q 'kyverno_policy_results_total' <<<"$expr" || fail_out "rule.yaml - expr does not use kyverno_policy_results_total"
grep -q 'rule_result="fail"' <<<"$expr" || fail_out "rule.yaml - expr does not select rule_result=\"fail\""
grep -Eq 'increase\(|rate\(' <<<"$expr" || fail_out "rule.yaml - expr reads the counter directly; wrap it in increase() or rate()"

grep -Eq '^[[:space:]]*for:[[:space:]]*[0-9]+[smh]' <<<"$rule" || fail_out "rule.yaml - no 'for:' duration such as 10m"
grep -Eq 'severity:[[:space:]]*[A-Za-z]+' <<<"$rule" || fail_out "rule.yaml - no severity label"

echo "PASS: the stored alert rule names KyvernoPolicyViolations, uses increase()/rate() on the failure counter, and has a for: duration and a severity label."
exit 0
