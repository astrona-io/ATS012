# Question

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this question on: `terminal`

Kyverno v1.13.2 is installed. `batch-ns` and `platform-ns` exist. PolicyExceptions are already enabled and scoped to `platform-ns` on the admission and reports controllers. The `ClusterPolicy` `batch-require-limits` is live in `Enforce` mode: its rule `check-limits` requires CPU and memory limits on every Pod in `batch-ns`.

1.  Give the cleanup controller permission to delete exceptions. Create a `ClusterRole` of your own choice of name, labelled `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"`, that allows `get`, `list`, `watch` and `delete` on `policyexceptions` in the `kyverno.io` API group.
2.  Write and apply a `ClusterPolicy` named `require-exception-ttl` with `validationFailureAction: Enforce` and `spec.background: false`, with one validate rule named `check-ttl` that matches `PolicyException` resources and requires the label `cleanup.kyverno.io/ttl` to be present and non-empty.
3.  Prove it works: attempt to create a `PolicyException` named `no-ttl` in `platform-ns` **without** the label and confirm it is **rejected**. `no-ttl` must not exist when you finish.
4.  Create a `PolicyException` named `allow-batch-timeboxed` in `platform-ns` that:
    *   carries the label `cleanup.kyverno.io/ttl: 8h` and the annotation `exception.company.io/owner` with any sensible value;
    *   waives the `check-limits` rule of `batch-require-limits` **and** its autogen counterpart;
    *   matches `Pod` resources in `batch-ns` whose names begin with `grace-`.
5.  Create a Pod named `grace-pod` in `batch-ns` with **no** resource limits and confirm it is **admitted**.
6.  Attempt to create a Pod named `strict-pod` in `batch-ns` with no resource limits and confirm it is **rejected**. `strict-pod` must not exist when you finish.
