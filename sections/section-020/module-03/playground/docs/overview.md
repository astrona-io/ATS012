# Overview: Time-Boxed Exceptions & Cleanup (Playground)

This is a **playground**, not a lab. It starts a fresh `kind` cluster with Kyverno v1.13.2 and a seeded starting state, and then waits. There is no task, no `astrona submit` and no pass or fail. Break things, `astrona destroy`, start over. `kubectl` already points at the cluster as the cluster administrator.

## What's in the box

- Namespaces `batch-ns` and `platform-ns`.
- PolicyExceptions enabled on the admission and reports controllers, scoped to `platform-ns`.
- `batch-require-limits` in `Enforce` mode (rule `check-limits`, matches `Pod` in `batch-ns`).
- The cleanup controller is running but has no RBAC rule to delete `PolicyException` objects.

## Practice ideas

- Create an exception labelled `cleanup.kyverno.io/ttl: 2m` and see that it is still there after two minutes: the cleanup controller cannot delete it.
- Add a ClusterRole labelled `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"` that allows `get`, `list`, `watch` and `delete` on `policyexceptions`, and watch the exception disappear.
- Check that the Pod that was admitted under the exception is blocked on its next rollout after expiry.
- Write a policy that requires the ttl label on every `PolicyException`.
- List exceptions with their ttl labels: `kubectl get policyexception -A -L cleanup.kyverno.io/ttl`.
