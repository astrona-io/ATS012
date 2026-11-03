# Summary

A metric is only useful once a question and a threshold sit on top of it.

## What you learned

A counter only goes up, so ask about change with `increase()` or `rate()` over a window, and sum across the label sets you do not care about, for example `sum by (policy_name) (increase(kyverno_policy_results_total{rule_result="fail"}[1h]))`. A latency histogram is read with `histogram_quantile(0.99, sum by (le) (rate(kyverno_admission_review_duration_seconds_bucket[5m])))`; the answer can be no better than the bucket boundaries you configured. The Prometheus Operator, a separate project, scrapes with a `ServiceMonitor` and evaluates alerts from a `PrometheusRule`. An alert needs an expression, a `for:` duration, a severity label and a runbook-style annotation. Good Kyverno alerts are about violations by policy, admission latency and controller errors, not about every counter.

Recording rules store the result of common queries so dashboards and alerts stay cheap. When data is missing, test each level in order: the controller endpoint, the Service endpoints, network access, the Prometheus target, and finally the query. An alert on `absent()` catches a metric that has vanished, which a threshold alert cannot.

The key facts to remember are these:

- Counters need `increase()` or `rate()`; gauges are read directly.
- `histogram_quantile` needs the `_bucket` series and `sum by (le)`.
- `ServiceMonitor` scrapes; `PrometheusRule` alerts.
- Alert on a symptom with a `for:` clause, not on a single sample.

<!-- astrona:playground:destroy -->
