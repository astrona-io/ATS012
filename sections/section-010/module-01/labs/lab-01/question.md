# Question

Solve this question on: `terminal`

Kyverno v1.13.2 is installed and the `platform-ns` namespace already exists and is empty.

1.  Write and apply a `ClusterPolicy` named `require-resource-limits` with `validationFailureAction: Audit` and a single validate rule named `check-limits`, matching `Pod` resources in the `platform-ns` namespace, requiring every container to set `resources.limits.cpu` and `resources.limits.memory`.
2.  Write and apply a second `ClusterPolicy` named `require-team-label`, also `Audit`, carrying the annotation `policies.kyverno.io/scored: "false"`, with a single validate rule named `check-team-label` matching `Pod` resources in `platform-ns` and requiring the label `team` to be set.
3.  Create a Pod named `compliant-pod` in `platform-ns` that satisfies both policies: it carries the label `team` and its container sets both CPU and memory limits.
4.  Create a Pod named `violator-pod` in `platform-ns` that satisfies neither: no `team` label and no resource limits. Confirm it is **admitted** — both policies are in `Audit` mode.
5.  Find the `PolicyReport` that describes `violator-pod`. Do not guess its name: look it up from the Pod's `metadata.uid`, or from the `KIND`/`NAME` columns of `kubectl get polr -n platform-ns -o wide`.
6.  Confirm that `violator-pod`'s report summary records **at least one `fail`** (from the scored policy) and **at least one `warn`** (from the advisory policy), and that `compliant-pod`'s report records neither.
7.  Print just the failing results of `violator-pod`'s report — policy name, rule name and message — using a jsonpath filter, without dumping the whole object.
