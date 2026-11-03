# Overview: Severity, Categories & Consuming Reports (Playground)

This is a **playground**, not a lab. It starts a fresh `kind` cluster with Kyverno v1.13.2 and a seeded starting state, and then waits. There is no task, no `astrona submit` and no pass or fail. Break things, `astrona destroy`, start over. `kubectl` already points at the cluster as the cluster administrator.

## What's in the box

- Namespaces `team-red` and `team-blue`, each holding workloads: `red-bad`, `red-good` and `blue-bad`.
- `require-resource-limits` (annotation `policies.kyverno.io/severity: high`, category `Best Practices`) and `require-team-label` (severity `medium`, category `Governance`), both `Audit`.
- The reports controller already scans every minute.

## Practice ideas

- Read one result with `kubectl get polr -n team-red -o yaml` and find the `severity` and `category` fields.
- Count `fail` results per severity across all namespaces with a jsonpath filter.
- Change the severity annotation on a policy and watch how long the report entries take to follow.
- Delete `red-bad` and see its report disappear; delete a policy and see its results leave the remaining reports.
- Create a policy matching `Namespace` and find the finding in `kubectl get cpolr`.
