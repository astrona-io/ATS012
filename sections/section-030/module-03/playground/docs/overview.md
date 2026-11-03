# Overview: Querying Metrics & Writing Alert Rules (Playground)

This is a **playground**, not a lab. It starts a fresh `kind` cluster with Kyverno v1.13.2 and a seeded starting state, and then waits. There is no task, no `astrona submit` and no pass or fail. Break things, `astrona destroy`, start over. `kubectl` already points at the cluster as the cluster administrator.

## What's in the box

- `default/metrics-probe`, a Pod with `curl`.
- Namespace `load-ns` with the `Enforce` policy `load-require-limits`.
- Three Pods that were admitted (`seed-ok-1` to `seed-ok-3`) and two attempts that were rejected, so `kyverno_policy_results_total` already has `pass` and `fail` series.

## Practice ideas

- Scrape the admission controller and write the PromQL you would use for the number of rejected requests in the last hour; then compute the plain number by hand from the scrape.
- Add up the `_bucket` series of `kyverno_admission_review_duration_seconds` to find the smallest `le` that holds every observation.
- Draft a `PrometheusRule` for `KyvernoPolicyViolations` and keep it in a ConfigMap. The Prometheus Operator is not installed here.
- Create more rejected requests and confirm a counter only ever goes up, even if you restart nothing.
- Restart the admission controller and observe what happens to the counters.
- Walk the troubleshooting order against the stock install: endpoint, Service endpoints, NetworkPolicy, then write the `absent()` expression you would alert on.
