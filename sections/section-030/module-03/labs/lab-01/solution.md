# Solution

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-03/labs/lab-01
```

## Step 1: Generate load

Three Pods with limits, which the policy admits:

```sh
for i in 1 2 3; do
kubectl apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: ok-$i
  namespace: load-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
      resources:
        limits:
          cpu: 100m
          memory: 64Mi
YAML
done
```

Two Pods without limits, which the policy rejects. The apply command prints the policy's message and exits with an error; that is the point:

```sh
for i in 1 2; do
kubectl apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: bad-$i
  namespace: load-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
YAML
done
kubectl get pods -n load-ns
```

Only the three `ok-` Pods should be listed. Grade it:

```sh
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-03/labs/lab-01 --keep
```

The check `load-was-generated` should pass.

## Step 2: Read the counters

```sh
kubectl exec metrics-probe -n default -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics > /tmp/metrics.txt

grep '^kyverno_policy_results_total' /tmp/metrics.txt | grep 'policy_name="load-require-limits"'
grep '^kyverno_admission_review_duration_seconds_count' /tmp/metrics.txt
```

Each series line ends with its value. Add up the `rule_result="pass"` lines whose `rule_execution_cause` is `admission_request`, then do the same for `rule_result="fail"`. For the review count, add up the value of every `_count` line. A short way to sum is:

```sh
grep '^kyverno_policy_results_total' /tmp/metrics.txt | grep 'policy_name="load-require-limits"' \
  | grep 'rule_result="pass"' | grep 'rule_execution_cause="admission_request"' \
  | awk '{s += $NF} END {print s}'
```

Change `pass` to `fail` for the second number. Use the counters' current values; the checker accepts a figure between what you generated and what the endpoint reports when it grades, because counters only grow.

## Step 3: Record the findings

Substitute the numbers you found:

```sh
kubectl create configmap metrics-findings -n load-ns \
  --from-literal=pass-total=<pass> \
  --from-literal=fail-total=<fail> \
  --from-literal=admission-review-count=<reviews>
```

## Step 4: Write the alert

```sh
cat > rule.yaml <<'YAML'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kyverno-alerts
  namespace: kyverno
spec:
  groups:
    - name: kyverno
      rules:
        - alert: KyvernoPolicyViolations
          expr: sum by (policy_name) (increase(kyverno_policy_results_total{rule_result="fail"}[15m])) > 10
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Policy {{ $labels.policy_name }} failed more than 10 times in 15 minutes"
YAML
kubectl create configmap kyverno-alert-rule -n load-ns --from-file=rule.yaml=rule.yaml
```

Grade it:

```sh
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-03/labs/lab-01
```

All three checks should pass.

## Common mistakes

- Summing the series without filtering on `rule_execution_cause`. Background scans add results that are not admission requests.
- Writing `expr: kyverno_policy_results_total{rule_result="fail"} > 10`. A counter compared directly keeps firing after the failures stop, and resets when Kyverno restarts.
- Leaving out `for:`. One noisy scrape then pages someone.
