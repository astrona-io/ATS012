# Part 1 — Reading Kyverno Metrics with PromQL

## Counters only go up

`kyverno_policy_results_total` counts every policy rule result since the controller started. A value of 4,812 tells you nothing: is that a lot, and is it growing? A restart resets it to zero, so even comparing two scrapes by eye is unreliable.

PromQL answers "how much did it change" with two functions on a **range vector** (a metric plus a window such as `[1h]`):

| Function | Returns |
|---|---|
| `increase(m[1h])` | the total growth over the last hour, adjusted for counter resets |
| `rate(m[5m])` | the per-second average growth over the last five minutes |

Use `increase` when a person will read the number ("37 failures this hour"), and `rate` when you will compare to a per-second threshold or feed another function.

## Aggregating away the labels you do not need

Each label combination is its own series. To ask "failures per policy", add up everything else:

```promql
sum by (policy_name) (
  increase(kyverno_policy_results_total{rule_result="fail"}[1h])
)
```

`sum by (policy_name)` keeps one series per policy and adds the rest together. `{rule_result="fail"}` is a label matcher that selects only failures. Remember from Module 2 that `resource_namespace` is not on by default; a query that groups by it returns nothing until you enable it.

## Which metric answers which question

| Question | Metric |
|---|---|
| How many rule results, and which were fail? | `kyverno_policy_results_total` with `rule_result` |
| How many admission requests did Kyverno see? | `kyverno_admission_requests_total` |
| How long do admission reviews take? | `kyverno_admission_review_duration_seconds` (histogram) |
| Why did a rule run: admission or background scan? | the `rule_execution_cause` label on rule results |

The last row is a classic confusion. A `fail` from a background scan is a resource that already existed. A `fail` with cause `admission_request` is a request that was just blocked or audited. Filter on the cause when the two have different owners.

## Latency from a histogram

A histogram is exposed as three kinds of series: `_bucket` (a counter per upper bound `le`), `_sum` and `_count`. A percentile is computed from the buckets:

```promql
histogram_quantile(
  0.99,
  sum by (le) (rate(kyverno_admission_review_duration_seconds_bucket[5m]))
)
```

Three details people get wrong:

1. You must keep `le` in the `sum by`. Dropping it removes the thing the function needs.
2. The answer is interpolated inside a bucket, so it can be no more precise than your `bucketBoundaries` from Module 2. Coarse buckets give coarse percentiles.
3. The mean from `_sum / _count` hides tail latency. A webhook that is usually fast and sometimes very slow looks fine on a mean.

## Try it

In the playground, run `kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics` and find the `kyverno_policy_results_total` lines for `load-require-limits`. Try to create one more Pod in `load-ns` that breaks the policy, scrape again, and watch the right counter move by one.

