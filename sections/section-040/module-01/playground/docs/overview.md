# Overview: Testing Policies with the Kyverno CLI (Playground)

This is a **playground**, not a lab. It has the `kyverno` CLI v1.13.2 and a working directory, `/opt/kyverno-lab`. There is no task, no `astrona submit` and no pass or fail. Change any file and run the commands again.

## What's in the box

- `policy.yaml`, a `ClusterPolicy` named `require-limits` with the rule `check-limits`.
- `resources.yaml`, with the Pods `good-pod` (has limits) and `bad-pod` (has none).

## Practice ideas

- Run `kyverno apply policy.yaml --resource resources.yaml --detailed-results` and read each result.
- Write `kyverno-test.yaml` with one pass and one fail expectation, then run `kyverno test .`.
- Add a mutate policy that labels Pods and test it with `patchedResource`.
- Add a values file and a rule that reads a variable.
- Break an expectation on purpose and compare the exit code of `kyverno test .` before and after.
