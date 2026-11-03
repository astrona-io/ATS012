# Overview: Configuring Metrics & Controlling Cardinality (Playground)

This is a **playground**, not a lab. It starts a fresh `kind` cluster with Kyverno v1.13.2 and a seeded starting state, and then waits. There is no task, no `astrona submit` and no pass or fail. Break things, `astrona destroy`, start over. `kubectl` already points at the cluster as the cluster administrator.

## What's in the box

- Namespaces `watched-ns` and `excluded-ns`.
- `default/metrics-probe`, a Pod with `curl`.
- The `kyverno-metrics` ConfigMap in the `kyverno` namespace with its shipped `namespaces`, `metricsExposure` and `bucketBoundaries`.

## Practice ideas

- Read the ConfigMap and note which labels `kyverno_policy_results_total` has by default.
- Enable `resource_namespace` by emptying `disabledLabelDimensions` for that metric, restart the admission controller and confirm the label appears.
- Exclude `excluded-ns` in `namespaces` and show that enforcement there is unchanged.
- Change `bucketBoundaries` and look at the `le` values of `kyverno_admission_review_duration_seconds_bucket`.
- Count the series before and after each change to see what cardinality costs.
