# Recording Rules and Dashboards

A query that scans a large set of series on every dashboard refresh is slow and expensive. This chapter covers recording rules, which compute common queries ahead of time, and how to build a useful Kyverno dashboard from them.

## Recording rules

A recording rule is a PromQL expression that Prometheus evaluates on a schedule. It stores the result as a new metric. Dashboards and alerts then read the cheap stored metric. By convention the name has the form `level:metric:operations`.

A recording rule lives next to alert rules in a `PrometheusRule` object:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kyverno-recording
  namespace: monitoring
spec:
  groups:
    - name: kyverno.rules
      interval: 1m
      rules:
        - record: policy:kyverno_policy_results:rate5m
          expr: sum by (policy_name, rule_result) (rate(kyverno_policy_results_total[5m]))
        - record: kyverno:admission_review_duration_seconds:p99_5m
          expr: histogram_quantile(0.99, sum by (le) (rate(kyverno_admission_review_duration_seconds_bucket[5m])))
```

The first rule keeps only the labels that the dashboard uses and drops the rest. The second precomputes the 99th percentile latency.

## Choosing panels

A short dashboard that answers real questions works better than one panel per metric. Four panels cover most needs:

- Failures per policy over time, from the policy results rate filtered to `rule_result="fail"`.
- Admission request rate, from `kyverno_admission_requests_total`.
- Admission review latency, the p99 recording rule above.
- Controller health, from `up` and the controller error metrics.

Use a rate for counters and show the latency in seconds. Put the time range and the scrape interval in your mind when you choose the rate window. The window should be at least four times the scrape interval, so that it always contains several samples.

## Rule checks before you apply

The Operator does not validate that your expression returns data. It only checks the syntax of the rules. Two checks are worth doing first:

```sh
promtool check rules kyverno-recording.yaml
promtool query instant http://prometheus.monitoring.svc:9090 'up{namespace="kyverno"}'
```

`promtool check rules` works on a plain rule file, so extract the `groups` section from the `PrometheusRule` first. The second command needs a reachable Prometheus.

> [!TIP]
> **Try it - write a recording rule**
>
> Write a `PrometheusRule` manifest with one recording rule that gives the failure rate per policy. Name it with the `level:metric:operations` form. You do not apply it in the playground, because the Operator is not installed. Check that the `expr` uses the exported counter name with `_total`.

## Common pitfalls

- Using a `rate()` window shorter than the scrape interval, which returns no data.
- Recording a rule with many labels, which defeats the purpose of saving cost.
- Referencing the documented name `kyverno_policy_results` instead of the exported `kyverno_policy_results_total`.
- Applying a `PrometheusRule` whose labels do not match the rule selector of the Prometheus instance, so it is never loaded.

## What you know now

You can precompute common queries and arrange them into a small dashboard. The last question is what to do when the data you expect is not there.
