# Overview: Reading PolicyReports (Playground)

This is a **playground**, not a lab. It starts a fresh `kind` cluster with Kyverno v1.13.2 and a seeded starting state, and then waits. There is no task, no `astrona submit` and no pass or fail. Break things, `astrona destroy`, start over. `kubectl` already points at the cluster as the cluster administrator.

## What's in the box

- Namespace `platform-ns` with two Pods: `compliant-pod` (team label, CPU and memory limits) and `violator-pod` (neither).
- Three `Audit` ClusterPolicies: `require-resource-limits` (scored, severity high), `require-team-label` (advisory, `policies.kyverno.io/scored: "false"`) and `require-namespace-owner` (matches the `finance` Namespace, so its finding lands in a `ClusterPolicyReport`).
- A namespace `finance` with no `owner` label, which `require-namespace-owner` flags.

## Practice ideas

- Find the report for `violator-pod` from its `metadata.uid`, then read `summary` and `results[]`.
- Confirm that `require-team-label` failures arrive as `warn`, not `fail`.
- Run `kubectl get cpolr -o wide` and find the finding for `finance`.
- Add the label `owner=ops` to `finance` and watch the `ClusterPolicyReport` entry change.
- Delete `violator-pod` and check that its report disappears.
