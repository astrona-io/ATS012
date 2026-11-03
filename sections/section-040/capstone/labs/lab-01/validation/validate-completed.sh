#!/usr/bin/env bash
# Section 040 capstone: confirms the test covers validate and mutate rules,
# run-tests.sh passes, and the test fails when the mutate policy changes.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

DIR=/opt/kyverno-capstone
cd "$DIR" 2>/dev/null || fail_out "$DIR - directory not found"

[[ -f kyverno-test.yaml ]] || fail_out "kyverno-test.yaml - file not found"
grep -q 'kind: Test' kyverno-test.yaml || fail_out "kyverno-test.yaml - kind is not Test"
grep -q 'patchedResource' kyverno-test.yaml || fail_out "kyverno-test.yaml - no patchedResource expectation for the mutate rule"
grep -q 'check-tag' kyverno-test.yaml || fail_out "kyverno-test.yaml - no expectation for rule check-tag"
grep -q 'add-team' kyverno-test.yaml || fail_out "kyverno-test.yaml - no expectation for rule add-team"
grep -Eq 'result:[[:space:]]*fail' kyverno-test.yaml || fail_out "kyverno-test.yaml - no expectation with result fail"
grep -q 'name: legacy' resources.yaml || fail_out "resources.yaml - legacy was removed; test the policy, do not change the resources"

[[ -f run-tests.sh ]] || fail_out "run-tests.sh - file not found"
bash -n run-tests.sh || fail_out "run-tests.sh - syntax error"
grep -q 'kyverno test' run-tests.sh || fail_out "run-tests.sh - does not call kyverno test"
bash run-tests.sh >/tmp/capstone-040.out 2>&1 || fail_out "run-tests.sh - exited non-zero; run it and read the output"

# The test must detect a wrong mutate policy.
tmp=$(mktemp -d)
cp -r "$DIR"/. "$tmp"/
sed -i.bak 's/platform$/wrong-team/' "$tmp/add-team-label.yaml"
if (cd "$tmp" && kyverno test . >/dev/null 2>&1); then
  rm -rf "$tmp"
  fail_out "the test still passes after the mutate policy label was changed - patchedResource must compare the full mutated Pod"
fi
rm -rf "$tmp"

echo "PASS: tests cover validate and mutate rules and fail on a wrong mutate policy."
exit 0
