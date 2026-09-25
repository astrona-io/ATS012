# Question

Solve this question on: `terminal`

Kyverno v1.13.2 is installed. `prod-ns` already contains a running Deployment named `payments-api` with no resource limits. `platform-ns` is your intended exception namespace. `rogue-ns` is an ordinary application namespace.

1.  Enable PolicyExceptions on **both** `kyverno-admission-controller` and `kyverno-reports-controller`, scoped with `--exceptionNamespace=platform-ns`, and lower the reports controller's `--backgroundScanInterval` to `1m`. Wait for the rollouts.
2.  Write and apply a `ClusterPolicy` named `prod-require-limits`: `validationFailureAction: Enforce`, `background: true`, one validate rule named `check-limits` matching `Pod` resources in `prod-ns` and requiring `resources.limits.cpu` and `resources.limits.memory` on every container.
3.  Write and apply a hygiene `ClusterPolicy` named `require-exception-metadata`: `Enforce`, `spec.background: false`, one rule named `check-owner-and-expiry` matching `PolicyException` resources and requiring the annotations `exception.company.io/owner` and `exception.company.io/expires` to be present and non-empty.
4.  Create a `PolicyException` named `allow-payments-api` in `platform-ns`, carrying both required annotations, waiving the `check-limits` rule of `prod-require-limits` **and its autogen counterpart** for `Pod` and `Deployment` resources in `prod-ns` whose names begin with `payments-api`.
5.  Force `payments-api` to roll a new Pod and confirm it is **admitted** despite still having no resource limits.
6.  Now test the scoping. Create a second `PolicyException` named `rogue-exception` in **`rogue-ns`** (with both required annotations so the hygiene policy accepts it) that waives the same rules for `Pod` resources in `prod-ns` whose names begin with `rogue`.
7.  Attempt to create a Pod named `rogue-pod` in `prod-ns` with no resource limits. It must be **rejected**: `rogue-exception` lives outside the namespace named by `--exceptionNamespace`, so Kyverno ignores it entirely. `rogue-pod` must not exist when you finish.
8.  Confirm the audit trail: a report result in `prod-ns` shows `result: skip` with `properties.exceptions` naming `allow-payments-api`, and **no** report result anywhere names `rogue-exception`.
