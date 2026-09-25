# Question

Solve this question on: `terminal`

Kyverno v1.13.2 is installed. Two namespaces already hold workloads created **before** any policy existed:

*   `prod-ns/billing-api` — no resource limits, no `team` label.
*   `staging-ns/checkout-api` — CPU and memory limits set, but no `team` label.

1.  Patch `kyverno-reports-controller` so background scans run every minute (`--backgroundScanInterval=1m`) and wait for the rollout.
2.  Write and apply a scored `ClusterPolicy` named `capstone-require-limits`: `validationFailureAction: Audit`, `background: true`, one validate rule named `check-limits` matching `Pod` resources in `prod-ns` and `staging-ns`, requiring `resources.limits.cpu` and `resources.limits.memory` on every container.
3.  Write and apply an advisory `ClusterPolicy` named `capstone-require-team-label`: the annotation `policies.kyverno.io/scored: "false"`, `validationFailureAction: Audit`, `background: true`, one validate rule named `check-team-label` matching `Pod` resources in `prod-ns` and `staging-ns`, requiring the label `team`.
4.  Write and apply a third `ClusterPolicy` named `capstone-admission-only` with `spec.background: false`, `validationFailureAction: Audit`, and one validate rule named `check-reviewed-label` matching `Pod` resources in `prod-ns`, requiring the label `reviewed`.
5.  Wait for a background scan cycle, then confirm the reporting state:
    *   `prod-ns` has at least one `fail` (limits) **and** at least one `warn` (team label).
    *   `staging-ns` has at least one `warn` (team label) and **zero** `fail` — it already sets limits.
    *   Neither pre-existing Deployment was deleted, modified, or restarted.
6.  Confirm that **no** report entry anywhere references `capstone-admission-only` for the pre-existing `billing-api` workload — `spec.background: false` keeps it out of every background scan.
7.  Now create a Pod named `reviewed-check-pod` in `prod-ns` with no `reviewed` label, and confirm that its report **does** carry a `capstone-admission-only` result — proving the policy is live at admission time even though background scanning never touches it.
