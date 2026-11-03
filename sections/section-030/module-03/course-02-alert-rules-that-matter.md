# Part 2 — Alert Rules That Matter

## Two objects, two jobs

The Prometheus Operator is a separate project that Kyverno does not install. If you run it, two of its custom resources do the work:

- **`ServiceMonitor`** tells the Operator what to scrape: which Service, which port. Kyverno's metrics Service is `kyverno-svc-metrics` on port 8000.
- **`PrometheusRule`** holds recording and alerting rules that Prometheus evaluates.

Mixing them up is the most common mistake: a `ServiceMonitor` never alerts, and a `PrometheusRule` never scrapes.

## Anatomy of an alert

```yaml
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
```

- **`expr`** is any PromQL that returns a series when the condition is true.
- **`for`** is how long the condition must hold before the alert fires. It filters out a single noisy scrape.
- **`labels.severity`** is what routing in Alertmanager keys on.
- **`annotations`** carry the human text, and a runbook link is a good addition.

## The four alerts worth having

1. **Violations by policy.** The example above. Tune the threshold to a normal day.
2. **Admission latency.** `histogram_quantile(0.99, ...)` above your webhook budget for several minutes. Slow policy slows every API request.
3. **Controller errors.** Any non-zero rate of `kyverno_controller_errors_total` held for a while.
4. **No data.** `absent(kyverno_policy_results_total)` or a failed scrape: a monitoring system that silently stopped is worse than one that is loud.

Resist alerting on every counter. An alert that fires without a clear action trains people to ignore the pager.

## Keeping alerts quiet and honest

- Use `for:` on everything except the "no data" case, where it should be short.
- Alert on a symptom a person can act on, not on a raw number that merely sounds important.
- Test the expression in a query UI before wrapping it in a rule. A rule with a typo in a label name evaluates to nothing and never fires, and nothing tells you.
- Remember the counter reset: using `increase` or `rate` already handles a Kyverno restart, a bare comparison of the counter does not.

## Try it

Write the `PrometheusRule` above to a file and check it carries what a reviewer would look for: an `alert` name, an `expr` that uses `increase(` or `rate(` on `kyverno_policy_results_total` with `rule_result="fail"`, a `for:` and a `severity` label. The lab asks for exactly this.

Next: [Summary](./course-03-summary.md)
