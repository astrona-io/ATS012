# Part 4 — Policy Settings That Shape Reports

Controller flags decide how often reports are produced. The policy itself decides whether a policy produces reports at all, and on which path. This part covers the policy fields that change the content of reports and explains the limits that background evaluation places on a rule.

## validationFailureAction

`spec.validationFailureAction` on a `ClusterPolicy` sets what happens when a `validate` rule fails on an admission request. In `Enforce` mode the request is rejected and the admission path writes no failing report entry for it. In `Audit` mode the request is admitted and the failure is recorded.

A policy can use `Enforce` for most namespaces and `Audit` for some. The `validationFailureActionOverrides` list does this, with one entry per action and a list of namespaces:

```yaml
spec:
  validationFailureAction: Enforce
  validationFailureActionOverrides:
    - action: Audit
      namespaces:
        - quiet-ns
```

Existing resources are not blocked by either mode. They are always evaluated by the background scan, and the scan records `fail` for them even under `Enforce`.

## spec.background

`spec.background` defaults to `true`. With `true`, the policy is evaluated on the admission path and by the background scan. With `false`, the policy is evaluated only at admission, so resources created before the policy never appear in its results.

<!-- astrona:playground:renew -->

```sh
kubectl get cpol -o custom-columns='NAME:.metadata.name,BACKGROUND:.spec.background,ACTION:.spec.validationFailureAction'
```

Run this command to see the three settings for every policy at once. A policy with `BACKGROUND` empty uses the default, `true`.

## What background mode cannot use

A background scan has no admission request. Variables that come from the request, such as `request.userInfo`, `request.operation` and the roles and cluster roles of the requester, do not exist during the scan. Kyverno rejects a policy that sets `background: true` and uses such variables, with an error that names the variable.

For a rule that depends on who made the request, set `spec.background: false`. The cost is that the rule has no coverage for existing resources.

## spec.admission

`spec.admission` defaults to `true` and controls whether the policy runs on the admission path. Setting it to `false` while `background` stays `true` makes a policy that is a pure scan: it never delays a request and still fills the reports. Use this when you want findings without any effect on deployments.

## When a policy change shows up

When you change a policy, the reports controller re-evaluates the resources that policy matches and updates their reports. You do not need to wait a full scan interval for a policy edit, but the update is not instant on a large cluster. A report older than your edit has not been refreshed yet.

> [!TIP]
> **Try it**
>
> Run the custom-columns command above. Apply a policy with `spec.background: false` and one with the default, both in `Audit` mode. Then compare the reports for a Deployment that was created before either policy.

You can now decide, per policy, whether it reports on admission, in the background, or both, and you know why a request-based rule cannot be scanned.

## Common pitfalls

> [!WARNING]
> - Expecting an `Enforce` policy to show rejected requests in a report. A rejected request is never created, so no resource exists to report on.
> - Setting `background: false` to silence a noisy policy. It also removes the policy from the scan of every existing resource.
> - Using `request.userInfo` in a policy that must report on existing resources. Move that check to a separate policy with `background: false`.
