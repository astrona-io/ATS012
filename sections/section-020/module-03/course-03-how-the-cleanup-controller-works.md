# Part 3 — How the Cleanup Controller Works

The `cleanup.kyverno.io/ttl` label is only a label. The component that acts on it is the Kyverno cleanup controller, a separate Deployment named `kyverno-cleanup-controller` in the `kyverno` namespace. To use time-boxed exceptions with confidence, you must know what this controller watches, when it deletes, and how to see what it did.

## What the controller watches

The cleanup controller handles two features: cleanup policies, and the ttl label. For the ttl label it watches resources that carry `cleanup.kyverno.io/ttl`. It can only watch and delete resource types that its ServiceAccount has RBAC permission for. That is why the aggregated ClusterRole from the first part is required for `policyexceptions`.

## Value formats

The label value is one of two forms:

- A duration, for example `30m`, `2h` or `24h`. The deadline is the creation time of the object plus the duration.
- An absolute time, in the format the Kyverno cleanup documentation describes.

Kubernetes label values have limits: they may contain only letters, digits, `-`, `_` and `.`, and at most 63 characters. A value must not contain spaces. A duration is the simplest form to use.

## Timing

The controller does not delete the object at the exact second. It computes the deadline, and deletes the object when it processes the item after that time. Plan with a margin of a few minutes, not seconds. A ttl of `1m` in a test cluster can take longer to show effect than expected.

Anyone who can edit the label of an existing exception can change its deadline, and so extend it. RBAC on `update` of `policyexceptions` is therefore a sensitive permission.

## Seeing what happened

The controller writes a log line for each deletion. Read the log:

```sh
kubectl -n kyverno logs deploy/kyverno-cleanup-controller --tail=100
```

If the log shows an authorization error such as `forbidden` for `policyexceptions`, the RBAC rule is missing. Check that the ClusterRole carries the label `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"` and that its rules list `delete`.

You can also test the permission without waiting for a deadline:

```sh
kubectl auth can-i delete policyexceptions \
  --as=system:serviceaccount:kyverno:kyverno-cleanup-controller -A
```

An answer of `yes` means the role is in place.

> [!TIP]
> **Try it - check permission before creating the exception**
>
> Run the `kubectl auth can-i` command before the ClusterRole exists, and note the answer. Apply the ClusterRole and run it again. Only then create an exception with a ttl of a few minutes.

## Common pitfalls

- Creating a ClusterRole without the aggregation label. It exists, but the controller does not receive it.
- Using a value with a space in the label. Kubernetes rejects the object.
- Expecting deletion at the exact second of the deadline.
- Giving many users `update` on `policyexceptions`. They can postpone any deadline.

## Where this leaves you

You know what the cleanup controller reads, how it decides, and how to verify its permission and its actions. The last part adds a second control, a cleanup policy, for exceptions that were created without a ttl.
