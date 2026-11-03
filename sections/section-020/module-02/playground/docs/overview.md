# Overview: Narrowing, Governing & Auditing Exceptions (Playground)

This is a **playground**, not a lab. It starts a fresh `kind` cluster with Kyverno v1.13.2 and a seeded starting state, and then waits. There is no task, no `astrona submit` and no pass or fail. Break things, `astrona destroy`, start over. `kubectl` already points at the cluster as the cluster administrator.

## What's in the box

- Namespaces `batch-ns` and `platform-ns`.
- PolicyExceptions enabled on the admission and reports controllers, scoped to `platform-ns`; reports controller scans every minute.
- `batch-require-limits` in `Enforce` mode (rule `check-limits`, matches `Pod` in `batch-ns`).

## Practice ideas

- Write an exception with a `conditions` block that only covers Pods labelled `exempt: "true"`.
- Write a hygiene policy that requires owner and expiry annotations on every `PolicyException`, with `background: false`.
- Try a `podSecurity` exclusion on a Pod Security Standards policy.
- List every exemption in force: `kubectl get policyexception -A` and the `skip` results in reports.
- Compare an exception with an `exclude` block for the same workload.
