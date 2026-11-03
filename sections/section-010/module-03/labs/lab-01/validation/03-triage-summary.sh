#!/usr/bin/env bash
# The ConfigMap platform-ns/triage-summary must hold the live count of fail results
# per severity, counted across every PolicyReport.

set -u

count_fail() {
  kubectl get polr -A -o jsonpath="{range .items[*].results[?(@.severity==\"$1\")]}{.result}{\"\\n\"}{end}" 2>/dev/null | grep -c '^fail$' || true
}

if ! kubectl get configmap triage-summary -n platform-ns >/dev/null 2>&1; then
  echo "FAIL: triage-summary - ConfigMap not found in platform-ns"
  exit 1
fi

live_high=$(count_fail high)
live_medium=$(count_fail medium)
if [[ "$live_high" -lt 1 || "$live_medium" -lt 1 ]]; then
  echo "FAIL: reports - expected at least one high and one medium fail result across all namespaces, found high=$live_high medium=$live_medium"
  exit 1
fi

got_high=$(kubectl get configmap triage-summary -n platform-ns -o jsonpath='{.data.high-fail}')
got_medium=$(kubectl get configmap triage-summary -n platform-ns -o jsonpath='{.data.medium-fail}')
if [[ "$got_high" != "$live_high" ]]; then
  echo "FAIL: triage-summary - high-fail is '$got_high', the reports hold $live_high fail result(s) with severity high"
  exit 1
fi
if [[ "$got_medium" != "$live_medium" ]]; then
  echo "FAIL: triage-summary - medium-fail is '$got_medium', the reports hold $live_medium fail result(s) with severity medium"
  exit 1
fi

echo "PASS: triage-summary records high-fail=$got_high and medium-fail=$got_medium, matching the live reports."
exit 0
