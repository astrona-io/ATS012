# Question

Solve this question on: `terminal`

Kyverno v1.13.2 is installed. Two namespaces already exist, each with a Deployment that was created **before** any policy — `legacy-ns/legacy-api` and `quiet-ns/noisy-api`, neither of which sets resource limits on its container.

Your job is to get `legacy-api` into a `PolicyReport` promptly, while `quiet-ns` stays out of reporting altogether.

Do the configuration work **before** you apply the policy.

1.  Inspect `kyverno-reports-controller`'s container args and note the current values of `--backgroundScanInterval` and `--skipResourceFilters`.
2.  Add the entry `[*/*,quiet-ns,*]` to the `resourceFilters` key of the `kyverno` ConfigMap in the `kyverno` namespace, **keeping the existing default entries intact**.
3.  Patch `kyverno-reports-controller` so that it both honours `resourceFilters` during background scans (`--skipResourceFilters=false`) and scans every minute (`--backgroundScanInterval=1m`). Wait for the rollout to finish.
4.  Write and apply a `ClusterPolicy` named `audit-resource-limits` with `validationFailureAction: Audit` and `background: true`, containing a single validate rule named `check-limits` that matches `Pod` resources in **both** `legacy-ns` and `quiet-ns` and requires `resources.limits.cpu` and `resources.limits.memory` on every container.
5.  Wait for a background scan cycle, then confirm `kubectl get polr -n legacy-ns -o wide` shows at least one failing result for the pre-existing workload — without `legacy-api` being deleted, modified, or restarted.
6.  Confirm `kubectl get polr -n quiet-ns` returns nothing at all, even though `noisy-api` violates exactly the same rule and the policy matches its namespace.
