# Part 1 — The kyverno-metrics ConfigMap

> Prerequisite: [Module landing page](./course.md). Next: [Part 2 — Using Metrics in Practice](./course-02-using-metrics-in-practice.md).

## Where the configuration lives

Metrics configuration is not on the policies and not (mostly) on the container args. It is one ConfigMap:

```sh
kubectl get configmap kyverno-metrics -n kyverno -o yaml
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kyverno-metrics
  namespace: kyverno
data:
  namespaces: '{"exclude":[],"include":[]}'
  metricsExposure: '{"kyverno_admission_requests_total":{"disabledLabelDimensions":["resource_namespace"]},"kyverno_admission_review_duration_seconds":{"disabledLabelDimensions":["resource_namespace"]},"kyverno_cleanup_controller_deletedobjects_total":{"disabledLabelDimensions":["resource_namespace","policy_namespace"]},"kyverno_policy_execution_duration_seconds":{"disabledLabelDimensions":["resource_namespace","resource_request_operation"]},"kyverno_policy_results_total":{"disabledLabelDimensions":["resource_namespace","policy_namespace"]},"kyverno_policy_rule_info_total":{"disabledLabelDimensions":["resource_namespace","policy_namespace"]}}'
  bucketBoundaries: '0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 15, 20, 25, 30'
```

Each controller reads it through the `METRICS_CONFIG` environment variable, which is why the same ConfigMap governs all four.

## `namespaces` — which namespaces are measured at all

A JSON object with two lists:

```json
{"exclude": ["kube-system", "monitoring"], "include": []}
```

- **`include`** empty means *all namespaces*. Populate it and only those namespaces are measured.
- **`exclude`** removes namespaces, and **takes precedence** over `include`.

This is the biggest, bluntest cardinality lever you have. On a large cluster, excluding the handful of namespaces that generate most of the churn — CI build namespaces, per-PR preview environments — can cut the series count dramatically while losing nothing you would actually alert on.

```sh
kubectl -n kyverno patch configmap kyverno-metrics --type=merge -p \
  '{"data":{"namespaces":"{\"exclude\":[\"ci-builds\"],\"include\":[]}"}}'
```

The value is a JSON *string* inside YAML, so the inner quotes need escaping. If that makes you nervous, `kubectl edit configmap kyverno-metrics -n kyverno` and edit it as text.

> [!WARNING]
> **Common pitfall**
>
> Excluding a namespace from metrics and expecting policies to stop applying there. These are unrelated systems: `namespaces` in `kyverno-metrics` controls *measurement*, `resourceFilters` in the `kyverno` ConfigMap controls *evaluation*. A namespace excluded from metrics is still fully policed — you have just stopped counting.

## `metricsExposure` — per-metric label control

A JSON object keyed by metric name. Two settings per metric:

- **`disabledLabelDimensions`** — a list of labels to drop from that metric's series.
- **`enabled`** — `false` switches the metric off entirely.

Note that the keys here use the **exported** names, with the `_total` suffix: `kyverno_policy_results_total`, not `kyverno_policy_results`.

The shipped defaults drop `resource_namespace` and `policy_namespace` from the highest-cardinality families. The arithmetic is the whole justification: a cluster with 200 namespaces, 30 policies and 4 resource kinds has roughly 24,000 possible `kyverno_policy_results_total` series before namespace labels, and 4.8 million after. Prometheus will store that; your budget may not.

To turn one dimension back on — for example because you genuinely need per-namespace failure attribution — set that metric's `disabledLabelDimensions` to an empty list.

A merge patch replaces the **whole** `metricsExposure` string: whatever you write becomes the complete configuration, and any metric you omit reverts to the code's built-in defaults rather than to the shipped ConfigMap's. So copy the existing value and change only the entry you care about. A YAML patch file keeps the JSON readable, since it avoids escaping every quote:

```sh
kubectl -n kyverno patch configmap kyverno-metrics --type=merge --patch-file=/dev/stdin <<'EOF'
data:
  metricsExposure: '{"kyverno_admission_requests_total":{"disabledLabelDimensions":["resource_namespace"]},"kyverno_admission_review_duration_seconds":{"disabledLabelDimensions":["resource_namespace"]},"kyverno_cleanup_controller_deletedobjects_total":{"disabledLabelDimensions":["resource_namespace","policy_namespace"]},"kyverno_policy_execution_duration_seconds":{"disabledLabelDimensions":["resource_namespace","resource_request_operation"]},"kyverno_policy_results_total":{"disabledLabelDimensions":[]},"kyverno_policy_rule_info_total":{"disabledLabelDimensions":["resource_namespace","policy_namespace"]}}'
EOF
```

Every entry is the shipped default except `kyverno_policy_results_total`, whose disabled list is now empty. Turn a dimension on for the one metric you will actually read it on, not globally.

> As an analogy: label dimensions are the columns of a spreadsheet where every distinct row must be stored forever. Adding `resource_namespace` does not add one column — it multiplies the rows by the number of namespaces you have. Enable it where you will actually read it, and nowhere else.

## `bucketBoundaries` — histogram resolution

A comma-separated list of second values, applied to the duration histograms (`kyverno_admission_review_duration_seconds`, `kyverno_policy_execution_duration_seconds`). The default spans 5ms to 30s in fifteen buckets.

```sh
kubectl -n kyverno patch configmap kyverno-metrics --type=merge -p \
  '{"data":{"bucketBoundaries":"0.01, 0.1, 1, 5, 10"}}'
```

Fewer buckets means fewer series and coarser quantiles. Boundaries are also a *series* multiplier — each boundary is one `le` label value on every otherwise-distinct combination — so trimming an over-detailed default is a legitimate cardinality saving on a busy cluster. The trade is precision: with the list above, a `histogram_quantile(0.99, ...)` can only tell you the p99 is somewhere between 10ms and 100ms.

## Making a change take effect

The instruments — their names, their label sets, their bucket boundaries — are built when a controller starts. Changing the ConfigMap does not retroactively rebuild them, so a change to `metricsExposure` or `bucketBoundaries` needs a restart of the controllers whose metrics you changed:

```sh
kubectl -n kyverno rollout restart deployment kyverno-admission-controller
kubectl -n kyverno rollout restart deployment kyverno-reports-controller
kubectl -n kyverno rollout status deployment/kyverno-admission-controller --timeout=180s
kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s
```

Restarting resets every counter to zero — they are process-lifetime counters. That is normal and Prometheus handles it (`rate()` and `increase()` are counter-reset aware), but it does mean an absolute value you were watching starts again from nothing.

> [!TIP]
> **Try it — turn on per-namespace attribution and prove it**
>
> ```sh
> kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
>   | grep '^kyverno_policy_results' | head -2        # no resource_namespace label
>
> kubectl -n kyverno patch configmap kyverno-metrics --type=merge --patch-file=/dev/stdin <<'EOF'
> data:
>   metricsExposure: '{"kyverno_policy_results_total":{"disabledLabelDimensions":[]}}'
> EOF
> kubectl -n kyverno rollout restart deployment kyverno-admission-controller
> kubectl -n kyverno rollout status deployment/kyverno-admission-controller --timeout=180s
>
> # generate some traffic, then scrape again
> kubectl -n metrics-ns run probe-pod --image=nginx:alpine
> kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
>   | grep '^kyverno_policy_results' | grep resource_namespace | head -2
> ```
>
> The label appears — and every namespace you have just became its own set of series.

## Reference

- `kubectl get configmap kyverno-metrics -n kyverno -o yaml` — the live configuration.
- [Kyverno docs — Monitoring](https://kyverno.io/docs/monitoring/) — the ConfigMap keys and their Helm equivalents.
