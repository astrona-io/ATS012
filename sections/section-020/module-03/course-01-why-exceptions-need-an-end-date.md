# Part 1 — Why Exceptions Need an End Date

Exceptions are granted at a moment of pressure: a release is late, a vendor image cannot run without root, a migration is half done. The person granting it means "for now". Nothing in the object says "for now". Six months later the exception is part of the furniture, the team that asked for it has been reorganised, and nobody remembers which rule it waives or why.

That is the **decay problem**, and the fix is not better memory. The fix is to give every exception an end date that the cluster itself enforces.

## What a good expiry looks like

- **Short.** Hours or days for an incident, weeks for a migration. Rarely longer than a quarter.
- **Attached at creation.** Not added later by a reviewer who may forget.
- **Enforced by a machine.** A human-readable `expires` annotation is documentation; it deletes nothing.
- **Renewable on purpose.** Extending an exception is a decision someone makes again, not a default.

## The `cleanup.kyverno.io/ttl` label

Kyverno ships a cleanup controller. Beyond the `CleanupPolicy` resource, it also honours one label on any object in the cluster:

```yaml
metadata:
  labels:
    cleanup.kyverno.io/ttl: 8h
```

The value is either a duration such as `30m`, `8h` or `48h`, or an absolute time such as `2026-12-31T23:00:00Z` or a plain date. For a duration the controller counts from the object's creation time and deletes the object when the time is up. For a `PolicyException`, deletion means the waiver is gone and the rule applies again.

Two properties matter:

1. **It is a label, not an annotation.** An annotation named `.../ttl` is ignored. This is the most common mistake.
2. **Deletion is not a rollback.** Workloads that were admitted because of the exception stay. The next admission of a similar Pod is judged by the rule, and the next background scan reports the existing Pods as failing.

## The RBAC the controller needs

The cleanup controller can only delete what its service account may delete. By default that does not include `PolicyException`. Kyverno builds the controller's ClusterRole by **aggregation**: any ClusterRole carrying a specific label is merged in.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cleanup-policyexceptions
  labels:
    rbac.kyverno.io/aggregate-to-cleanup-controller: "true"
rules:
  - apiGroups: ["kyverno.io"]
    resources: ["policyexceptions"]
    verbs: ["get", "list", "watch", "delete"]
```

You can check the result without waiting for an expiry:

```bash
kubectl auth can-i delete policyexceptions.kyverno.io -n platform-ns \
  --as=system:serviceaccount:kyverno:kyverno-cleanup-controller
```

`yes` means the controller will be able to do its job. `no` means a ttl label will sit on the object doing nothing. That silent failure is why the lab grades the RBAC before the exception.

## Try it

In the playground, apply the ClusterRole above, run the `can-i` command until it says `yes`, then create a throwaway exception with `cleanup.kyverno.io/ttl: 1m` and watch it disappear. The cleanup controller checks periodically, so allow a little more than the stated minute.

