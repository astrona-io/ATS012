# Part 2 — The Core Metric Families

> Prerequisite: [Part 1 — The Metrics Endpoint and Its Services](./course-01-metrics-endpoint-and-services.md). Next: [Module 2 — Configuring Metrics & Controlling Cardinality](../module-02/course.md).

## The `_total` surprise

Kyverno's documentation calls the results metric `kyverno_policy_results`. Your endpoint calls it `kyverno_policy_results_total`. Both are right.

Kyverno instruments with OpenTelemetry and exports to Prometheus. The Prometheus exporter follows the Prometheus naming convention that counters end in `_total`, so it appends the suffix at export time. The instrument's name in the code and the docs has no suffix; the series you query does.

The practical rule: **when writing PromQL, use the name exactly as it appears on the endpoint.** When reading the docs, expect the suffix to be missing. And when grepping the raw endpoint, grep the prefix — `grep '^kyverno_policy_results'` matches either.

## The six families worth knowing by name

### `kyverno_policy_results_total` — what happened, per evaluation

A counter, incremented once per rule evaluation. This is the workhorse.

| Label | Values |
| :--- | :--- |
| `policy_name` | the policy's name |
| `policy_namespace` | namespace of a `Policy`, or `-` for a `ClusterPolicy` |
| `policy_type` | `cluster`, `namespaced` |
| `policy_validation_mode` | `enforce`, `audit` |
| `policy_background_mode` | `true`, `false` |
| `rule_name` | the rule's name |
| `rule_type` | `validate`, `mutate`, `generate` |
| `rule_result` | `pass`, `fail` |
| `rule_execution_cause` | `admission_request`, `background_scan` |
| `resource_kind` | `Pod`, `Deployment`, … |
| `resource_namespace` | the resource's namespace (**disabled by default** — see Module 2) |
| `resource_request_operation` | `create`, `update`, `delete` |

`rule_execution_cause` is the label that makes this metric genuinely useful: it separates "policies blocking live traffic" from "background scan re-confirming the same old violations", which are very different operational signals that would otherwise be summed together.

```promql
# failures per rule over the last 24h, admission traffic only
sum(increase(kyverno_policy_results_total{rule_result="fail", rule_execution_cause="admission_request"}[24h])) by (policy_name, rule_name)
```

### `kyverno_policy_rule_info_total` — what exists

A **gauge**, not a counter, despite the `_total` suffix: it reports `1` for each rule currently active in the cluster, carrying `policy_name`, `policy_type`, `policy_validation_mode`, `policy_background_mode` and `rule_type` labels. It is an inventory, not an event count.

```promql
# how many distinct policies are live in enforce mode
count(count(kyverno_policy_rule_info_total{policy_validation_mode="enforce"} == 1) by (policy_name))
```

This is the metric to alert on when a policy *disappears*. A rule vanishing from the inventory because somebody deleted a policy is invisible in every other family — no failures, no latency, just silence where enforcement used to be.

### `kyverno_admission_requests_total` — how much traffic the webhook sees

A counter over admission requests Kyverno was called for, labelled by `resource_kind`, `resource_request_operation` and `request_allowed`. Use it for load, and for the blunt "how many requests are we rejecting" number:

```promql
sum(rate(kyverno_admission_requests_total{request_allowed="false"}[5m]))
```

### `kyverno_admission_review_duration_seconds` — the latency you are adding to the cluster

A histogram of end-to-end admission review time. This is the number to put in front of anyone nervous about installing a policy engine, and the first thing to look at when the cluster feels slow after a policy rollout.

```promql
histogram_quantile(0.99, sum(rate(kyverno_admission_review_duration_seconds_bucket[5m])) by (le))
```

Histograms expose three series per family — `_bucket`, `_sum`, `_count` — and `histogram_quantile` needs the `_bucket` one. The bucket boundaries are configurable; Module 2 covers changing them.

### `kyverno_policy_execution_duration_seconds` — which policy is slow

The same idea, one level down: how long individual rule evaluation takes, labelled by `rule_type`, `resource_kind` and `resource_request_operation`. When admission review latency rises, this tells you whether one expensive rule is responsible — typically a rule making external API calls or doing heavy `foreach` work.

### `kyverno_policy_changes_total` — who has been editing policy

A counter of policy create/update/delete events. Cheap, small, and exactly what you want when the question is "enforcement changed at some point last night — when?"

```promql
increase(kyverno_policy_changes_total[1h])
```

## Everything else, briefly

- `kyverno_client_queries_total` — Kyverno's own calls to the Kubernetes API. Climbing steeply usually means a policy is doing API lookups on a hot path.
- `kyverno_controller_reconcile_total`, `_requeue_total`, `_drop_total` — per-controller work queues. Drops are the alertable one.
- `kyverno_cleanup_controller_deletedobjects_total`, `_errors_total` — what `CleanupPolicy` has actually deleted.
- `kyverno_info` — a gauge carrying the build version as labels, handy for confirming what is really running.

> [!TIP]
> **Try it — make a metric move**
>
> With an `Enforce` policy live in `metrics-ns`:
>
> ```sh
> kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
>   | grep '^kyverno_policy_results' | grep 'rule_result="fail"'
>
> kubectl -n metrics-ns run breaker --image=nginx:alpine     # blocked by the policy
>
> kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
>   | grep '^kyverno_policy_results' | grep 'rule_result="fail"'
> ```
>
> The counter on the matching series goes up by one. You have just watched a rejected `kubectl` command become a number a dashboard can graph.

> [!WARNING]
> **Common pitfall**
>
> Treating `kyverno_policy_rule_info_total` as a counter because of its name and wrapping it in `rate()` or `increase()`. It is a gauge whose value is `1` per active rule — `rate()` over it produces meaningless near-zero numbers. Use `count(... == 1)` to count rules, and save `rate()`/`increase()` for the real counters.

## Self-check

1. The docs say `kyverno_policy_results`; your endpoint says `kyverno_policy_results_total`. Which do you put in a PromQL query, and why do they differ?
2. Which label separates admission-time evaluations from background-scan evaluations, and why does mixing them mislead?
3. A policy was deleted overnight and nobody noticed. Which metric family would have caught it?
4. You need a p99 for admission latency. Which of the three histogram series does `histogram_quantile` need?

## Reference

- [Kyverno docs — Metrics reference](https://kyverno.io/docs/reference/metrics/) — the full list of exported metric names.
- [Kyverno docs — Monitoring](https://kyverno.io/docs/monitoring/) — per-metric pages with label tables and example queries.
