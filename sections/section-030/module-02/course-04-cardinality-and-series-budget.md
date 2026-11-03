# Cardinality and the Series Budget

Every label value that appears creates a new time series, and each series costs memory in Kyverno and in Prometheus. This chapter shows how to count series and how to keep the count under control with the configuration you already know.

## What cardinality means

Cardinality is the number of distinct time series. A series is one metric name together with one exact set of label values. The count grows by multiplication. A metric with 20 policies, 3 rules each, 4 results, 2 request operations and 10 resource kinds can reach 20 x 3 x 4 x 2 x 10 = 4800 series, if every combination occurs.

Adding the `resource_namespace` label multiplies that number again by the number of namespaces. This is why Kyverno disables that label on `kyverno_policy_results_total` by default.

## Measuring what you have

Prometheus can count its own data. These queries show which Kyverno metrics are the largest:

```promql
count({__name__=~"kyverno_.*"})
topk(10, count by (__name__) ({__name__=~"kyverno_.*"}))
```

The first returns the total number of Kyverno series. The second lists the ten metric names with the most series. Histograms create one series per bucket boundary per label set, plus `_sum` and `_count`, so a histogram with many boundaries is expensive.

From the endpoint directly, count lines for one family:

```sh
kubectl exec -n default metrics-probe -- \
  curl -s http://kyverno-svc-metrics.kyverno:8000/metrics \
  | grep -c '^kyverno_admission_review_duration_seconds_bucket'
```

## Ways to reduce series

You have four levers, all in the `kyverno-metrics` ConfigMap:

- Exclude namespaces that you do not need to measure, such as system or ephemeral test namespaces, with `namespaces.exclude`.
- Keep high-cost labels in `disabledLabelDimensions`, so a metric aggregates across them.
- Reduce `bucketBoundaries` to the few values that match the latency you care about.
- Switch a metric off with `enabled: false` when nothing uses it.

Each lever has a cost in detail. Dropping a label means you can no longer group by it. Fewer buckets means coarser percentiles. Decide from the questions you need to answer, not from the metric list.

## Churn

Cardinality also grows over time when label values keep changing. Resource names are the classic case. Kyverno does not use a resource name label by default, so a cluster that creates thousands of short-lived Pods does not create thousands of series. If you enable a label that holds a changing value, old series stay in Prometheus until retention removes them.

> [!TIP]
> **Try it - measure before and after**
>
> Count the lines that start with `kyverno_` on the endpoint. Then exclude the `metrics-ns` namespace in the ConfigMap, restart the admission controller, create a Pod in another namespace and count again. Compare the two numbers.

## Common pitfalls

- Enabling a label dimension to solve one question and leaving it on for months.
- Adding many bucket boundaries for precision, which multiplies series for every label set.
- Looking only at Kyverno memory use. The larger cost is usually storage and query time in Prometheus.
- Excluding a namespace and expecting enforcement to stop there. Exclusion affects metrics only.

## What you know now

You can estimate and measure series counts, and you know the four configuration levers that reduce them. The next step is to turn the numbers that remain into alerts.
