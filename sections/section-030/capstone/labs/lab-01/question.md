# Question

Solve this question on: `terminal`

Kyverno v1.13.2 is installed. `svc-a-ns` is a production service namespace you want fully measured. `ci-ns` is a high-churn CI namespace whose metrics you do not want to pay for — but which must still be policed exactly as strictly. A `metrics-probe` Pod with `curl` is running in the `default` namespace.

Configure metrics **before** generating traffic; restarting a controller resets every counter.

1.  Patch the `kyverno-metrics` ConfigMap so that:
    *   `namespaces` excludes `ci-ns`;
    *   `metricsExposure` keeps every shipped entry except `kyverno_policy_results_total`, whose `disabledLabelDimensions` becomes an empty list;
    *   `bucketBoundaries` is exactly `0.02, 0.2, 2`.
2.  Restart the admission controller and wait for the rollout.
3.  Write and apply a `ClusterPolicy` named `capstone-metrics-limits` with `validationFailureAction: Enforce`, `background: true`, and one validate rule named `check-limits` matching `Pod` resources in **both** `svc-a-ns` and `ci-ns`, requiring `resources.limits.cpu` and `resources.limits.memory` on every container.
4.  In `svc-a-ns`, create a Pod named `svc-a-ok` that sets both limits — it must be **admitted**.
5.  In `svc-a-ns`, attempt a Pod named `svc-a-bad` with no limits — it must be **rejected** and must not exist when you finish.
6.  In `ci-ns`, attempt a Pod named `ci-bad` with no limits — it must be **rejected** too, and must not exist when you finish. Enforcement is identical in both namespaces; only measurement differs.
7.  From the metrics endpoint alone, prove all of the following:
    *   `kyverno_policy_rule_info_total` shows `capstone-metrics-limits` with `policy_validation_mode="enforce"`.
    *   `kyverno_policy_results_total` has series with `resource_namespace="svc-a-ns"` for both `rule_result="pass"` and `rule_result="fail"`.
    *   **No** metric series anywhere mentions `ci-ns`.
    *   `kyverno_admission_requests_total` records at least one `request_allowed="false"`.
    *   `kyverno_admission_review_duration_seconds_bucket` exposes `le="0.02"` and no longer exposes the default `le="0.025"`.
