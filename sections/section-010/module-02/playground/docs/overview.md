# Overview: The Reports Pipeline & Its Tuning (Playground)

This is a **playground**, not a lab. It starts a fresh `kind` cluster with Kyverno v1.13.2 and a seeded starting state, and then waits. There is no task, no `astrona submit` and no pass or fail. Break things, `astrona destroy`, start over. `kubectl` already points at the cluster as the cluster administrator.

## What's in the box

- `legacy-ns/legacy-api` and `quiet-ns/noisy-api`: two Deployments created before any policy, neither sets resource limits.
- Kyverno v1.13.2 with default flags: the reports controller scans in the background every hour.
- No ClusterPolicy and no report yet.

## Practice ideas

- Inspect the reports controller args: `kubectl -n kyverno get deploy kyverno-reports-controller -o jsonpath='{.spec.template.spec.containers[0].args}'`.
- Apply an `Audit` policy with `background: true` for both namespaces, then create a new Pod and compare how fast its report appears with the Deployment's.
- Lower `--backgroundScanInterval` to `1m` and watch the old Deployment appear.
- Add `[*/*,quiet-ns,*]` to `resourceFilters` and flip `--skipResourceFilters` to see when `quiet-ns` stops being reported.
- List `admissionreports,backgroundscanreports -A` and check which ClusterRoles carry `rbac.kyverno.io/aggregate-to-reports-controller`.
- Compare `spec.background: false` with the default on a pre-existing Deployment.
- List `ephemeralreports -A` while you create Pods, to catch the staging objects.
