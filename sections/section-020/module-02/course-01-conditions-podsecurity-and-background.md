# Part 1 — Narrowing an Exception: conditions, podSecurity & background

> Prerequisite: [Module landing page](./course.md). Next: [Part 2 — Governance, Alternatives & Auditing](./course-02-governance-and-alternatives.md).

## Why `match` alone is usually too coarse

`match` selects on the shape of the resource's identity: kind, namespace, name, labels. That is fine when the thing you are exempting is genuinely identified by its name, and dangerous when it is not. `names: ["legacy-api*"]` is a prefix, and prefixes are an invitation — the next person to name a workload `legacy-api-v2` inherits an exemption nobody granted them.

Two fields let you add a second, independent test that a resource must also satisfy.

## `spec.conditions`

`conditions` takes the same `any`/`all` shape as a policy's `preconditions`, with the same `key`/`operator`/`value` triples and the same JMESPath variable substitution:

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: allow-migration-jobs
  namespace: platform-ns
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
            - Job
          namespaces:
            - batch-ns
  conditions:
    all:
      - key: "{{ request.object.metadata.labels.exempt || '' }}"
        operator: Equals
        value: "true"
```

Read that as two independent gates. `match` says *which* resources are candidates: Pods and Jobs in `batch-ns`. `conditions` says a candidate is only actually exempted if it *also* carries the label `exempt: "true"` at the moment it is evaluated.

(A label key containing dots or slashes has to be quoted inside the JMESPath expression — `request.object.metadata.labels."kyverno.io/exempt"` — which is why the example uses a plain key.)

The practical difference from putting the label in `match.resources.selector` is who controls the exemption and how visibly. A `match` selector is part of the exception's own identity — you edit the exception to change scope. A `conditions` gate reads live request data, so the same exception can cover a class of resources while requiring each individual resource to opt itself in explicitly. The workload's manifest then *shows*, in its own labels, that it is claiming an exemption. That is a much better artifact to find during a code review than a name buried in an exception three repositories away.

The `|| ''` in that expression is defensive: without it, a Pod that has no labels at all makes the variable substitution fail, and a failed substitution produces an `error` result rather than a clean non-match.

## `spec.podSecurity`

Kyverno ships the Pod Security Standards as policies whose rules use a `validate.podSecurity` block covering many individual controls at once — `Privileged Containers`, `Host Namespaces`, `Running as Non-root`, `Capabilities`, and so on. Waiving the whole rule to unblock one container that needs one capability is a sledgehammer.

`spec.podSecurity` on an exception lets you waive a single named control instead:

```yaml
spec:
  exceptions:
    - policyName: psa-baseline
      ruleNames:
        - baseline
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - monitoring
  podSecurity:
    - controlName: "Host Namespaces"
      images:
        - "docker.io/prometheus/node-exporter*"
```

Every other control in the rule keeps enforcing on that Pod. `controlName` must match the standard's control name exactly as the Pod Security Standards define it; `images` narrows the exemption to containers running specific images, and `restrictedField` (with `values`) can pin it to a specific field and set of allowed values.

This is the most surgical exemption Kyverno offers: one control, one image, one namespace — and everything else in the baseline still applies.

## `spec.background`

`background` on an exception (default `true`) controls whether the exception is honoured during background scans, exactly mirroring the field on a policy. Leave it at the default in almost every case: an exception honoured at admission but not during scanning produces reports that contradict your enforcement, which is the confusing state Module 1 warned about — only this time you did it to yourself in YAML instead of in a flag.

Set it to `false` only when the exception's `conditions` reference data that exists solely in an admission request, such as `request.userInfo` or `request.operation`. Those cannot be evaluated against an object sitting in etcd, so honouring the exception in a background scan would be meaningless.

> [!TIP]
> **Try it — prove the condition gate actually gates**
>
> With the `allow-migration-jobs` exception above applied and an `Enforce` policy in place:
>
> ```sh
> # no opt-in label: still blocked
> kubectl -n batch-ns run no-optin --image=nginx:alpine
>
> # opt-in label present: admitted
> kubectl -n batch-ns run with-optin --image=nginx:alpine --labels='exempt=true'
> kubectl get pods -n batch-ns
> ```
>
> Same namespace, same kind, same missing resource limits, same exception object. The only difference is a label the workload's author had to write down.

> [!WARNING]
> **Common pitfall**
>
> Writing `key: "{{ request.object.metadata.labels.exempt }}"` without a `|| ''` fallback. On a resource with no labels the substitution fails, and a failed substitution in an exception's `conditions` does not politely evaluate to "no match" — it surfaces as an `error` result in the report, and the rule outcome is not what you expect.

## Reference

- `kubectl explain policyexception.spec.conditions` / `kubectl explain policyexception.spec.podSecurity` — the exact schema on your cluster.
- [Kyverno docs — Policy Exceptions](https://kyverno.io/docs/exceptions/) — including the full `podSecurity` exemption shape.
