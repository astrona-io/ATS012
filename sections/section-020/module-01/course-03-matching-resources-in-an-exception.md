# Part 3 — Matching Resources in an Exception

An exception that matches too much waives a rule for workloads you never reviewed. An exception that matches too little does nothing, and the policy keeps blocking. This part explains how the `match` block selects resources, so you can write one that covers exactly the intended Pods.

## The shape of `match`

The `match` block of a `PolicyException` uses the same structure as the `match` block of a policy rule. It has two keys, `any` and `all`. Each key holds a list of filters, and each filter has a `resources` block.

- `any`: the exception applies if at least one filter matches (logical OR).
- `all`: the exception applies only if every filter matches (logical AND).

```yaml
spec:
  exceptions:
    - policyName: require-resource-limits
      ruleNames:
        - check-limits
        - autogen-check-limits
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - legacy-ns
          names:
            - legacy-api-*
```

Inside `resources` you can combine `kinds`, `names`, `namespaces`, `selector` and `namespaceSelector`. All the fields inside one `resources` block must match together. The `names` field accepts wildcards: `*` matches any run of characters and `?` matches one character.

## Choosing between names and selectors

`names` matches on the object name. A Pod created by a Deployment has a generated name such as `legacy-api-7d9f8b6c5-x2x4q`, so a wildcard is needed to cover every replica and every rollout.

`selector` matches on labels of the resource itself. It is more stable than a name when a workload has a label that identifies it, for example `app: legacy-api`. A label also moves with the workload when the Deployment is renamed.

```yaml
  match:
    all:
      - resources:
          kinds:
            - Pod
          namespaces:
            - legacy-ns
          selector:
            matchLabels:
              app: legacy-api
```

`namespaceSelector` matches on the labels of the namespace that holds the resource. Use it when many namespaces share a label such as `tier: batch`, and you do not want to list them one by one.

## Why `namespaces` matters

If the `resources` block has no `namespaces`, the exception matches the resource in any namespace where the policy applies. A name wildcard such as `*` or `job-*` could then exempt a Pod in an unrelated team namespace. Always set `namespaces`, or a `namespaceSelector`, on an exception.

## The match must be inside the policy's own scope

An exception only waives a rule for a resource that the rule already matches. If the policy rule matches `Pod` in `legacy-ns`, an exception for a Pod in another namespace has no effect, because the rule never evaluates that Pod. The exception narrows the policy, it never widens it.

> [!TIP]
> **Try it - match by label instead of by name**
>
> Take the exception from the previous part and replace the `names` list with a `selector` on a label of the Pod template. Apply it, delete one Pod of the Deployment so the controller recreates it, and check the new Pod is admitted. Then create a second Pod in the same namespace without the label and confirm the policy still blocks it.

## Common pitfalls

- Matching only `Deployment` in `kinds`. The Pod is the resource that admission evaluates, so the `match` must cover `Pod` as well.
- Leaving `namespaces` out and exempting more than intended.
- Using a selector on labels that exist only on the Deployment object. The selector is applied to the Pod, so the label must be in the Pod template.
- Writing the policy and rule names correctly but a `match` that does not overlap the policy's own `match`. The result is an exception that never applies and no error message.

## Where this leaves you

You can now choose how to identify the resources an exception covers: by name wildcard, by label selector, or by namespace labels, combined with `any` and `all`. The next question is what to check when an exception is written correctly and still does not apply.
