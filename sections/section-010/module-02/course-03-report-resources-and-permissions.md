# Part 3 — Report Resources and Permissions

The reports pipeline stores its intermediate data in Kubernetes objects, and it can only scan what its service accounts may read. This part names the intermediate resource kinds, shows how to inspect them, and explains the permission rule that makes reports for custom resources silently empty.

## The intermediate resource kinds

Kyverno keeps intermediate data in the `reports.kyverno.io` API group, in four kinds. Two are namespaced and two are cluster-scoped, mirroring the split between `PolicyReport` and `ClusterPolicyReport`.

| Kind | Scope | Written by |
| :--- | :--- | :--- |
| `AdmissionReport` | Namespaced | The admission controller, for a request it evaluated |
| `ClusterAdmissionReport` | Cluster | The admission controller, for a cluster-scoped resource |
| `BackgroundScanReport` | Namespaced | The reports controller, from a background scan |
| `ClusterBackgroundScanReport` | Cluster | The reports controller, for a cluster-scoped resource |

The reports controller reads all four and merges them into the final `PolicyReport` or `ClusterPolicyReport` for each resource. If you see a report in a staging kind and not in the final kind, the merge step has not run for it yet.

## Inspect the staging objects

<!-- astrona:playground:renew -->

List the staging kinds with `kubectl api-resources`, then list the objects themselves while you create a workload:

```sh
kubectl api-resources --api-group=reports.kyverno.io
kubectl get admissionreports,backgroundscanreports -A
```

Use these commands to learn how the pipeline behaves. Do not build tooling on them. The staging kinds can change between Kyverno releases, and their content is already merged into the stable report.

## What the reports controller is allowed to read

The background scan reads every resource a policy matches. Kyverno runs the reports controller under its own service account, with a ClusterRole that covers the core Kubernetes kinds. It does not automatically cover custom resources added by other operators.

When a policy matches a kind the reports controller cannot read, the scan cannot list that kind. The result is a policy that is valid and a report that never appears, with an error in the reports controller log.

## Grant access with an aggregated ClusterRole

Kyverno builds its controller roles by aggregating ClusterRoles that carry a label. For the reports controller, the label is `rbac.kyverno.io/aggregate-to-reports-controller: "true"`. Create a ClusterRole with that label and the rules for the extra kind. The example grants read access to `certificates` from the `cert-manager.io` group:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno:reports:cert-manager
  labels:
    rbac.kyverno.io/aggregate-to-reports-controller: "true"
rules:
  - apiGroups: ["cert-manager.io"]
    resources: ["certificates"]
    verbs: ["get", "list", "watch"]
```

The admission controller and the background controller have matching labels, `aggregate-to-admission-controller` and `aggregate-to-background-controller`. Each controller needs its own grant for the work it does.

## Confirm the permission

`kubectl auth can-i` can impersonate the service account and answer directly:

```sh
kubectl auth can-i list certificates.cert-manager.io --as=system:serviceaccount:kyverno:kyverno-reports-controller
```

An answer of `no` means the aggregated role is missing or does not match. Check the log of the reports controller for the same failure.

> [!TIP]
> **Try it**
>
> Run `kubectl api-resources --api-group=reports.kyverno.io` and match each kind in the output to a row in the table above. Then run `kubectl get clusterroles -l rbac.kyverno.io/aggregate-to-reports-controller=true` to see which roles already feed the reports controller.

You now know the staging kinds, who writes them, and how to give the reports controller access to a custom resource kind.

## Common pitfalls

> [!WARNING]
> - Granting permissions to the wrong controller. Admission, background and reports controllers have separate service accounts and separate aggregation labels.
> - Editing the generated ClusterRole directly. Kyverno recomputes it from the labelled roles, so your edit is lost. Create a separate labelled role.
> - Assuming a missing report means the policy is wrong. For custom resources, check permissions before you edit the policy.
