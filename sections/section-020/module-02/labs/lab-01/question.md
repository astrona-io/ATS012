# Question

Solve this question on: `terminal`

Kyverno v1.13.2 is installed. `batch-ns` and `platform-ns` exist, and PolicyExceptions are already enabled and scoped to `platform-ns` on both the admission controller and the reports controller, with background scans running every minute.

1.  Write and apply a `ClusterPolicy` named `batch-require-limits` with `validationFailureAction: Enforce`, `background: true`, and one validate rule named `check-limits` matching `Pod` resources in `batch-ns`, requiring `resources.limits.cpu` and `resources.limits.memory` on every container.
2.  Write and apply a hygiene `ClusterPolicy` named `require-exception-metadata` with `validationFailureAction: Enforce` and `spec.background: false`, containing one validate rule named `check-owner-and-expiry` that matches `PolicyException` resources and requires both annotations `exception.company.io/owner` and `exception.company.io/expires` to be present and non-empty.
3.  Prove the hygiene policy works: attempt to create a `PolicyException` named `sloppy-exception` in `platform-ns` **without** those annotations and confirm it is **rejected**. `sloppy-exception` must not exist when you finish.
4.  Create a `PolicyException` named `allow-optin-batch` in `platform-ns` that:
    *   carries both required annotations (any sensible values);
    *   waives the `check-limits` rule of `batch-require-limits` and its autogen counterpart;
    *   matches `Pod` resources in `batch-ns`;
    *   adds a `conditions` block requiring the resource to carry the label `exempt` with the value `"true"`.
5.  Attempt to create a Pod named `no-optin` in `batch-ns` with no resource limits and **no** `exempt` label. Confirm it is **rejected** — the exception must not cover it. `no-optin` must not exist when you finish.
6.  Create a Pod named `with-optin` in `batch-ns` with no resource limits but **with** the label `exempt: "true"`. Confirm it is **admitted**.
7.  Confirm the exemption is auditable: a report result for `with-optin` must show `result: skip` with `properties.exceptions` naming `allow-optin-batch`.
