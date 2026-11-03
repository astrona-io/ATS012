# Overview: Enabling & Writing a PolicyException (Playground)

This is a **playground**, not a lab. It starts a fresh `kind` cluster with Kyverno v1.13.2 and a seeded starting state, and then waits. There is no task, no `astrona submit` and no pass or fail. Break things, `astrona destroy`, start over. `kubectl` already points at the cluster as the cluster administrator.

## What's in the box

- `legacy-ns/legacy-api`, a Deployment whose container sets no resource limits, created before the policy.
- An empty `platform-ns` for your exceptions.
- `require-resource-limits` in `Enforce` mode (rule `check-limits`, matches `Pod` in `legacy-ns`).
- PolicyExceptions are **not** enabled: the controllers run with default flags.

## Practice ideas

- Create an exception first, then show that nothing changes until the flags are set.
- Enable `--enablePolicyException=true` and `--exceptionNamespace=platform-ns` on the admission and reports controllers, and compare the report before and after.
- Write an exception that names only `check-limits` and see that new Deployment Pods stay blocked (the autogen trap), then fix it.
- Narrow the `match` to names beginning with `legacy-api` and prove another name is still blocked.
- Create an exception in `legacy-ns` instead of `platform-ns` and see that it is ignored.
