#!/usr/bin/env bash
# Module 040-01: confirms /opt/kyverno-lab/kyverno-test.yaml exists, expects
# pass for good-pod and fail for bad-pod, and that `kyverno test` exits 0.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

cd /opt/kyverno-lab 2>/dev/null || fail_out "/opt/kyverno-lab - directory not found"
[[ -f kyverno-test.yaml ]] || fail_out "kyverno-test.yaml - file not found in /opt/kyverno-lab"

grep -q 'kind: Test' kyverno-test.yaml || fail_out "kyverno-test.yaml - kind is not Test"
grep -q 'good-pod' kyverno-test.yaml || fail_out "kyverno-test.yaml - no expectation for good-pod"
grep -q 'bad-pod' kyverno-test.yaml || fail_out "kyverno-test.yaml - no expectation for bad-pod"
grep -Eq 'result:[[:space:]]*pass' kyverno-test.yaml || fail_out "kyverno-test.yaml - no expectation with result pass"
grep -Eq 'result:[[:space:]]*fail' kyverno-test.yaml || fail_out "kyverno-test.yaml - no expectation with result fail"

kyverno test . >/tmp/kyverno-test.out 2>&1 || fail_out "kyverno test - exited non-zero; read its output with 'kyverno test .'"

# The policy and the resources must be the ones the lab provided.
grep -q 'check-limits' policy.yaml || fail_out "policy.yaml - rule check-limits was changed or removed"
grep -q 'name: bad-pod' resources.yaml || fail_out "resources.yaml - bad-pod was removed; test the policy, do not change the resources"

echo "PASS: kyverno test succeeds with a pass and a fail expectation."
exit 0
