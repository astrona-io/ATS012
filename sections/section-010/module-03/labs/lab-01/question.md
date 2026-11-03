# Question

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this question on: `terminal`

Kyverno v1.13.2 is installed and the reports controller scans in the background every minute. The namespaces `team-red`, `team-blue` and `platform-ns` exist. Three Pods were created before any policy: `red-bad` and `red-good` in `team-red`, and `blue-bad` in `team-blue`. `red-good` has a `team` label and CPU and memory limits; `red-bad` and `blue-bad` have neither. No policy exists yet.

1.  Write and apply a `ClusterPolicy` named `require-resource-limits` with `validationFailureAction: Audit` and `background: true`. It carries the annotations `policies.kyverno.io/severity: high` and `policies.kyverno.io/category: Best Practices`, and has one validate rule named `check-limits` that matches `Pod` resources in `team-red` and `team-blue` and requires `resources.limits.cpu` and `resources.limits.memory` on every container.
2.  Write and apply a second `ClusterPolicy` named `require-team-label`, also `Audit` with `background: true`, with the annotations `policies.kyverno.io/severity: medium` and `policies.kyverno.io/category: Governance`. Its one validate rule is named `check-team`, matches `Pod` resources in `team-red` and `team-blue`, and requires the label `team` to be set and non-empty.
3.  Wait for the background scan, then read the results of `red-bad`'s report and find the `severity` and `category` fields on its entries.
4.  Delete the Pod `red-bad` and confirm that its `PolicyReport` disappears from `team-red` without you deleting the report.
5.  Count the results with `result: fail` and `severity: high`, and then the results with `result: fail` and `severity: medium`, across **all** namespaces, using one `kubectl get polr -A` query with a jsonpath filter for each.
6.  Create a ConfigMap named `triage-summary` in `platform-ns` with the key `high-fail` set to the first count and the key `medium-fail` set to the second count.
