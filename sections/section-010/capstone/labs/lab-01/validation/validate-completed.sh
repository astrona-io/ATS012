#!/usr/bin/env bash
# Section 010 capstone: confirms the tuned scan interval, the three-policy set
# (scored, advisory, admission-only), the expected fail/warn split across
# prod-ns and staging-ns, and that spec.background:false keeps a policy out of
# background reports while remaining live at admission.

set -u

fail_out() { echo "FAIL: $1"; exit 1; }

# --- policies -------------------------------------------------------------
kubectl get clusterpolicy capstone-require-limits >/dev/null 2>&1 \
  || fail_out "capstone-require-limits - ClusterPolicy not found"
kubectl get clusterpolicy capstone-require-team-label >/dev/null 2>&1 \
  || fail_out "capstone-require-team-label - ClusterPolicy not found"
kubectl get clusterpolicy capstone-admission-only >/dev/null 2>&1 \
  || fail_out "capstone-admission-only - ClusterPolicy not found"

for p in capstone-require-limits capstone-require-team-label capstone-admission-only; do
  a=$(kubectl get clusterpolicy "$p" -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null)
  [[ "$a" == "Audit" ]] || fail_out "$p - validationFailureAction is '$a', expected Audit"
done

scored=$(kubectl get clusterpolicy capstone-require-team-label -o jsonpath='{.metadata.annotations.policies\.kyverno\.io/scored}' 2>/dev/null)
[[ "$scored" == "false" ]] \
  || fail_out "capstone-require-team-label - annotation policies.kyverno.io/scored is '${scored:-unset}', expected \"false\""

bg=$(kubectl get clusterpolicy capstone-admission-only -o jsonpath='{.spec.background}' 2>/dev/null)
[[ "$bg" == "false" ]] \
  || fail_out "capstone-admission-only - spec.background is '${bg:-unset}', expected false"

kubectl get clusterpolicy capstone-require-limits -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw check-limits \
  || fail_out "capstone-require-limits - no rule named 'check-limits'"
kubectl get clusterpolicy capstone-require-team-label -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw check-team-label \
  || fail_out "capstone-require-team-label - no rule named 'check-team-label'"
kubectl get clusterpolicy capstone-admission-only -o jsonpath='{.spec.rules[*].name}' 2>/dev/null | grep -qw check-reviewed-label \
  || fail_out "capstone-admission-only - no rule named 'check-reviewed-label'"

# --- reports controller tuning -------------------------------------------
args=$(kubectl get deployment kyverno-reports-controller -n kyverno -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null)
interval=$(echo "$args" | tr ',' '\n' | grep -o 'backgroundScanInterval=[^"]*' | tail -1 | cut -d= -f2)
[[ "$interval" == "1m" ]] \
  || fail_out "kyverno-reports-controller - effective --backgroundScanInterval is '${interval:-unset}', expected 1m"

# --- pre-existing workloads untouched ------------------------------------
for pair in "prod-ns billing-api" "staging-ns checkout-api"; do
  set -- $pair
  ready=$(kubectl get deployment "$2" -n "$1" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [[ -n "$ready" && "$ready" -ge 1 ]] \
    || fail_out "$1/$2 - Deployment missing or not ready; reporting must never disturb a workload"
done

# --- prod-ns: at least one fail and at least one warn ---------------------
sum_max() { # namespace, summary field -> highest value across reports
  local best=0 v
  for v in $(kubectl get polr -n "$1" -o jsonpath="{range .items[*]}{.summary.$2}{\"\n\"}{end}" 2>/dev/null); do
    [[ "$v" -gt "$best" ]] && best="$v"
  done
  echo "$best"
}

prod_fail=0; prod_warn=0; stag_warn=0
for _ in $(seq 1 45); do
  prod_fail=$(sum_max prod-ns fail)
  prod_warn=$(sum_max prod-ns warn)
  stag_warn=$(sum_max staging-ns warn)
  if [[ "$prod_fail" -ge 1 && "$prod_warn" -ge 1 && "$stag_warn" -ge 1 ]]; then
    break
  fi
  sleep 5
done

[[ "$prod_fail" -ge 1 ]] \
  || fail_out "prod-ns - no PolicyReport records a fail; billing-api violates capstone-require-limits and the background scan should report it"
[[ "$prod_warn" -ge 1 ]] \
  || fail_out "prod-ns - no PolicyReport records a warn; the advisory team-label policy must be annotated policies.kyverno.io/scored: \"false\""
[[ "$stag_warn" -ge 1 ]] \
  || fail_out "staging-ns - no PolicyReport records a warn; checkout-api has no 'team' label"

stag_fail=$(sum_max staging-ns fail)
[[ "$stag_fail" -eq 0 ]] \
  || fail_out "staging-ns - a PolicyReport records $stag_fail fail result(s); checkout-api already sets CPU and memory limits, so the scored policy should pass there"

# --- background:false is absent from the background report ----------------
duid=$(kubectl get deployment billing-api -n prod-ns -o jsonpath='{.metadata.uid}' 2>/dev/null)
dpolicies=$(kubectl get polr "$duid" -n prod-ns -o jsonpath='{range .results[*]}{.policy}{"\n"}{end}' 2>/dev/null)
if echo "$dpolicies" | grep -qw "capstone-admission-only"; then
  fail_out "prod-ns/billing-api - its PolicyReport contains a capstone-admission-only result; spec.background:false must keep that policy out of background scans"
fi

# --- but live at admission ------------------------------------------------
kubectl get pod reviewed-check-pod -n prod-ns >/dev/null 2>&1 \
  || fail_out "reviewed-check-pod - Pod not found in prod-ns (it must be created, and admitted, since the policy is Audit)"

puid=$(kubectl get pod reviewed-check-pod -n prod-ns -o jsonpath='{.metadata.uid}' 2>/dev/null)
found=0
for _ in $(seq 1 30); do
  if kubectl get polr "$puid" -n prod-ns -o jsonpath='{range .results[*]}{.policy}{"\n"}{end}' 2>/dev/null | grep -qw "capstone-admission-only"; then
    found=1
    break
  fi
  sleep 4
done
[[ "$found" -eq 1 ]] \
  || fail_out "reviewed-check-pod - its PolicyReport has no capstone-admission-only result; the policy is Audit and should still evaluate at admission time"

echo "PASS: scan interval tuned to 1m, scored/advisory/admission-only policies behave correctly, prod-ns shows fail+warn, staging-ns shows warn only, and spec.background:false excluded the policy from background scans while staying live at admission."
exit 0
