# Part 4 — Cleanup Policies as a Safety Net

A validating policy can require the ttl label on new exceptions. It cannot fix exceptions that already exist, and it does nothing if someone turns it off. A cleanup policy is a second control that runs on a schedule and deletes matching resources. This part uses one to remove exceptions that have no end date.

## ClusterCleanupPolicy

A `ClusterCleanupPolicy` (API version `kyverno.io/v2`) has a cron `schedule`, a `match` block and optional `conditions`. At each run, the cleanup controller lists the matching resources, evaluates the conditions and deletes the resources for which the conditions are true.

```yaml
apiVersion: kyverno.io/v2
kind: ClusterCleanupPolicy
metadata:
  name: remove-old-exceptions
spec:
  schedule: "0 * * * *"
  match:
    any:
      - resources:
          kinds:
            - PolicyException
          namespaces:
            - platform-ns
  conditions:
    any:
      - key: "{{ time_diff('{{ target.metadata.creationTimestamp }}', '{{ time_now_utc() }}') }}"
        operator: GreaterThan
        value: "720h"
```

The schedule `0 * * * *` runs at the start of every hour. In the conditions, `target` is the resource being tested. The condition above is true for any exception older than 720 hours (30 days). The Kyverno JMESPath function `time_diff` returns the time between two timestamps as a duration.

A namespaced `CleanupPolicy` has the same fields and works only in its own namespace. Use it when each team manages the exceptions of its own namespace.

## RBAC again

A cleanup policy is also limited by RBAC. The cleanup controller needs `list` and `delete` on `policyexceptions`, so the same aggregated ClusterRole covers it.

## Choosing between the two controls

- The ttl label gives each exception its own deadline, chosen by the author.
- The cleanup policy gives all exceptions one maximum age, chosen by the platform team.
- The validating policy makes the label required so that the first control is always used.

Use all three. The validating policy stops new exceptions without an end date, the label sets the specific end, and the cleanup policy removes anything old that was missed.

## Selecting what to keep

If some exceptions are permanent by decision, exclude them with a label. Add a condition that tests for that label, so that the cleanup policy leaves them alone, and require review of the label itself in the validating policy.

> [!TIP]
> **Try it - delete by age**
>
> Apply the policy above with a `value` of `5m` and a schedule of `*/2 * * * *`. Create an exception and wait. The cleanup controller deletes it on a run after it is older than five minutes. Check with `kubectl get policyexception -A` and the cleanup controller log.

## Common pitfalls

- A `match` without `namespaces`. The policy then tests exceptions in every namespace.
- A schedule that runs too rarely for the maximum age you set.
- Forgetting that deletion is final. An exception that expires needs a new object, and the workload fails in the next scan.
- Writing the policy and not granting the cleanup controller RBAC. The policy is accepted and deletes nothing.

## Where this leaves you

You can combine a ttl label, a validating policy and a cleanup policy so that no exception outlives its purpose. You also know the signs that each control is not working: the controller log, the RBAC check and the report.
