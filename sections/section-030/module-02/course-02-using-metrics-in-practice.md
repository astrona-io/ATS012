# Part 2 — Using Metrics in Practice

> Prerequisite: [Part 1 — The kyverno-metrics ConfigMap](./course-01-the-kyverno-metrics-configmap.md). Next: [Final Domain Quiz](../../final-domain-quiz.md).

## The alerts worth having

Most Kyverno dashboards people build are graphs nobody looks at. These four are the ones that wake you up for a real reason.

**1. Enforcement disappeared.** A policy deleted or a rule removed is silent in every other signal — no errors, no latency, no failures, because nothing is being evaluated any more.

```promql
count(count(kyverno_policy_rule_info_total{policy_validation_mode="enforce"} == 1) by (policy_name)) < 5
```

Pin the threshold to the number of enforcing policies you expect. Crude, and it has caught more real incidents than anything clever.

**2. Admission latency is hurting the cluster.** Every millisecond here is added to every matching write in the cluster.

```promql
histogram_quantile(0.99, sum(rate(kyverno_admission_review_duration_seconds_bucket[5m])) by (le)) > 1
```

**3. Rejections spiked.** A sudden jump usually means a policy rollout is blocking something legitimate, and you would rather find out from an alert than from a team whose deploys have been failing for an hour.

```promql
sum(rate(kyverno_policy_results_total{rule_result="fail", rule_execution_cause="admission_request"}[5m])) > 1
```

**4. A controller is dropping work.** Requeues are normal backpressure; drops mean work was abandoned.

```promql
sum(rate(kyverno_controller_drop_total[5m])) > 0
```

## Diagnosing "the cluster got slow after we rolled out policy"

Work outward from the biggest number.

**Step 1 — is it actually Kyverno?** Look at the p99 of `kyverno_admission_review_duration_seconds`. If it is in single-digit milliseconds, admission control is not your problem and you can stop here with evidence rather than opinion.

**Step 2 — one policy or all of them?** Break the per-rule timing down:

```promql
topk(5, histogram_quantile(0.95, sum(rate(kyverno_policy_execution_duration_seconds_bucket[5m])) by (le, rule_type)))
```

`rule_type` is available by default. If you need per-policy attribution, that is exactly the kind of narrow, temporary dimension re-enable Part 1 described.

**Step 3 — is the policy calling out to the API?** A rule using `context` API lookups makes a Kubernetes API call per evaluation:

```promql
sum(rate(kyverno_client_queries_total[5m]))
```

A number that tracks your admission rate almost 1:1 means every admission is doing a lookup, and caching or restructuring that rule is the fix.

**Step 4 — is the webhook matching more than it should?** A rule matching `kinds: ["*"]` puts Kyverno in the path of every write in the cluster:

```promql
sum(rate(kyverno_admission_requests_total[5m])) by (resource_kind)
```

If `Event` or `Lease` appears near the top, something is matching far too broadly — those are the highest-churn objects in any cluster, which is exactly why a stock install filters them out in `resourceFilters`.

## Metrics, reports and events: three tools, three jobs

It is worth being explicit about which signal answers which question, because using the wrong one is how investigations go sideways.

| Question | Signal |
| :--- | :--- |
| Which specific resources are non-compliant right now? | `PolicyReport` / `ClusterPolicyReport` |
| Why did *this* `kubectl apply` fail, right now? | The admission error message, and Kubernetes Events |
| How often is this happening, and is it getting worse? | Metrics |
| Is Kyverno itself healthy and fast? | Metrics |
| Which exemptions are live? | Reports (`result: skip`, `properties.exceptions`) |

Metrics are aggregates: they will tell you that `require-limits` failed 412 times in the last hour, and they will never tell you which Pods. Reports are an inventory: they will name every non-compliant resource, and they will not tell you whether the number is rising. You need both, and the domain you have just finished is both halves.

> [!TIP]
> **Try it — watch a counter rise under load**
>
> ```sh
> before=$(kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
>   | grep '^kyverno_admission_requests_total' | awk '{s+=$NF} END {print s+0}')
>
> for i in 1 2 3 4 5; do kubectl -n metrics-ns run load-$i --image=nginx:alpine; done
>
> after=$(kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
>   | grep '^kyverno_admission_requests_total' | awk '{s+=$NF} END {print s+0}')
> echo "before=$before after=$after"
> ```
>
> The delta is larger than five — each Pod creation is several admission requests once the ReplicaSet, status updates and Kyverno's own objects are counted.

> [!WARNING]
> **Common pitfall**
>
> Alerting on the raw value of a counter (`kyverno_policy_results_total > 100`). Counters reset to zero whenever a controller restarts, so such an alert fires forever after a busy week and then goes quiet after a routine rollout. Always wrap counters in `rate()` or `increase()`, which understand resets.

## Self-check

1. Which metric would tell you that somebody deleted your enforcing policy, and why is it silent in every other family?
2. Admission p99 is 40ms and a team blames Kyverno for slow deploys. What do you say, and what do you show them?
3. `kyverno_client_queries_total` is rising in lockstep with admission traffic. What is the likely cause?
4. You need to know *which Pods* are violating a policy. Metrics or reports, and why?

## Reference

- [Kyverno docs — Monitoring](https://kyverno.io/docs/monitoring/) — per-metric documentation and Grafana dashboards.
- `kubectl get servicemonitor -n kyverno` — the scrape configuration a Prometheus Operator install picks up automatically.
