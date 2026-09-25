# Question

Solve this question on: `terminal`

Kyverno v1.13.2 is installed. `legacy-ns` already contains a running Deployment named `legacy-api` whose container sets no resource limits. An empty namespace `platform-ns` exists for your exceptions.

1.  Write and apply a `ClusterPolicy` named `require-resource-limits` with `validationFailureAction: Enforce`, `background: true`, and one validate rule named `check-limits` matching `Pod` resources in `legacy-ns`, requiring `resources.limits.cpu` and `resources.limits.memory` on every container.
2.  Prove the policy blocks: attempt to create a Deployment named `new-api` in `legacy-ns` with no resource limits and confirm the request is **rejected**. `new-api` must not exist when you finish.
3.  Enable PolicyExceptions on **both** `kyverno-admission-controller` and `kyverno-reports-controller`, scoped to `platform-ns` (`--enablePolicyException=true` and `--exceptionNamespace=platform-ns`). Wait for both rollouts.
4.  Also lower the reports controller's `--backgroundScanInterval` to `1m` so you can see the report change within the lab.
5.  Create a `PolicyException` named `allow-legacy-api` in `platform-ns` that waives the `check-limits` rule of `require-resource-limits` — **and its autogen counterpart** — for `Pod` and `Deployment` resources in `legacy-ns` whose names begin with `legacy-api`.
6.  Force `legacy-api` to roll a new Pod (for example by adding an annotation to its Pod template) and confirm the new Pod is **admitted** despite still having no resource limits.
7.  Confirm the exemption is visible in the reports: at least one result in `legacy-ns` must show `result: skip` with `properties.exceptions` naming `allow-legacy-api`.
