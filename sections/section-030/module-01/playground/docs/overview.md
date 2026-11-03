# Overview: The Metrics Endpoint & Core Metric Families (Playground)

This is a **playground**, not a lab. It starts a fresh `kind` cluster with Kyverno v1.13.2 and a seeded starting state, and then waits. There is no task, no `astrona submit` and no pass or fail. Break things, `astrona destroy`, start over. `kubectl` already points at the cluster as the cluster administrator.

## What's in the box

- `default/metrics-probe`, a Pod with `curl`, for scraping from inside the cluster.
- Namespace `metrics-ns` with the `Enforce` policy `metrics-demo-limits` and one admitted Pod `metrics-pass-pod`.
- Kyverno v1.13.2 with the stock `kyverno-metrics` ConfigMap.

## Practice ideas

- Scrape all four metrics Services and compare what each exposes: `kubectl -n kyverno get svc | grep metrics`.
- Try to create a Pod without limits in `metrics-ns` and watch `kyverno_policy_results_total` gain a `fail` series.
- List the labels of `kyverno_policy_results_total` and name the ones that separate admission from background scans.
- Find the gauge `kyverno_policy_rule_info_total` and count the rules by validation mode.
- Compare the `# TYPE` line of each family with the name you would write in PromQL.
- Run `kubectl get crd servicemonitors.monitoring.coreos.com` and note that it fails, because the Prometheus Operator is not installed here.
