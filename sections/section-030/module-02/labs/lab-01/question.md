# Question

Solve this question on: `terminal`

Kyverno v1.13.2 is installed. The namespaces `watched-ns` and `excluded-ns` exist, and a `metrics-probe` Pod with `curl` is running in the `default` namespace.

Do the configuration work **before** you generate any traffic.

1.  Read the `kyverno-metrics` ConfigMap in the `kyverno` namespace and note the shipped values of `namespaces`, `metricsExposure` and `bucketBoundaries`. Confirm on the endpoint that `kyverno_policy_results_total` currently carries **no** `resource_namespace` label.
2.  Patch the ConfigMap so that all three of the following are true:
    *   `namespaces` excludes `excluded-ns` (and includes everything else).
    *   `metricsExposure` keeps every shipped entry, except that `kyverno_policy_results_total` has an **empty** `disabledLabelDimensions` list — enabling per-namespace attribution.
    *   `bucketBoundaries` is exactly `0.01, 0.1, 1, 5, 10`.
3.  Restart the admission controller so the new instrument configuration is built, and wait for the rollout.
4.  Write and apply a `ClusterPolicy` named `metrics-config-limits` with `validationFailureAction: Audit`, `background: true`, and one validate rule named `check-limits` matching `Pod` resources in **both** `watched-ns` and `excluded-ns`, requiring `resources.limits.cpu` and `resources.limits.memory`.
5.  Create a Pod named `watched-pod` in `watched-ns` and a Pod named `excluded-pod` in `excluded-ns`, both with **no** resource limits. Both must be admitted — the policy is in `Audit` mode.
6.  Scrape the endpoint and confirm `kyverno_policy_results_total` now has at least one series carrying `resource_namespace="watched-ns"`, and that **no** metric series anywhere carries `resource_namespace="excluded-ns"`.
7.  Confirm the histogram buckets changed: `kyverno_admission_review_duration_seconds_bucket` must expose `le="0.01"` and must no longer expose the default boundary `le="0.025"`.
