# Question

Solve this question on: `terminal`

Kyverno v1.13.2 is installed, the `metrics-ns` namespace exists, and a Pod named `metrics-probe` is running in the `default` namespace with `curl` available.

1.  List the Services in the `kyverno` namespace and identify the four metrics Services and the port they share. Scrape the admission controller's endpoint from inside the cluster — for example `kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics` — and confirm you get Prometheus text output.
2.  Write and apply a `ClusterPolicy` named `metrics-demo-limits` with `validationFailureAction: Enforce`, `background: true`, and one validate rule named `check-limits` matching `Pod` resources in `metrics-ns`, requiring `resources.limits.cpu` and `resources.limits.memory` on every container.
3.  Confirm the policy shows up in the inventory metric: `kyverno_policy_rule_info_total` must have a series with `policy_name="metrics-demo-limits"`.
4.  Create a Pod named `metrics-pass-pod` in `metrics-ns` that sets both CPU and memory limits. It must be **admitted**.
5.  Attempt to create a Pod named `metrics-fail-pod` in `metrics-ns` with no resource limits. It must be **rejected**, and must not exist when you finish.
6.  Scrape the endpoint again and confirm `kyverno_policy_results_total` now has a series for `policy_name="metrics-demo-limits"` with `rule_result="pass"` **and** a series with `rule_result="fail"`, both with a non-zero value.
7.  Confirm `kyverno_admission_requests_total` is present and non-zero — the raw count of admission requests Kyverno handled while you were working.
