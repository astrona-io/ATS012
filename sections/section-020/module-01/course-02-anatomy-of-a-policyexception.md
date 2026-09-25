# Part 2 — The Anatomy of a PolicyException

> Prerequisite: [Part 1 — Enabling PolicyExceptions](./course-01-enabling-policyexceptions.md). Next: [Module 2 — Narrowing, Governing & Auditing Exceptions](../module-02/course.md).

## The whole object

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: allow-legacy-api
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
            - Deployment
          namespaces:
            - legacy-ns
          names:
            - "legacy-api*"
```

Four things to notice before we go field by field.

It is **namespaced** — `metadata.namespace` is mandatory, and it must be the namespace named by `--exceptionNamespace`. That namespace has nothing to do with where the exempted workload lives; an exception in `platform-ns` can exempt Pods in `legacy-ns`, and can exempt cluster-scoped resources too.

It names the policy **by name**, not by reference — there is no ownership link, no finalizer, no validation that the policy exists. Write `policyName: requre-resource-limits` with a typo and you get a perfectly valid object that exempts nothing.

It names **rules**, not policies-as-a-whole. An exception is a scalpel: this rule, on these resources.

And its `match` block is the **same match syntax you already know** from policies — `any`/`all`, `resources.kinds`, `namespaces`, `names`, `selector`. Everything you learned about selecting resources in a policy applies here unchanged.

## `spec.exceptions[]`

Each entry pairs one policy with the rules inside it to waive.

- **`policyName`** — the policy's name. For a namespaced `Policy` (as opposed to a `ClusterPolicy`), use the `<namespace>/<name>` form, e.g. `team-a/require-limits`. For a `ClusterPolicy`, the bare name.
- **`ruleNames`** — a list of rule names. `"*"` is accepted and waives every rule in the policy, which you should reach for only when you genuinely mean it.

You can list several `exceptions` entries to waive rules from several policies in one object.

## The autogen trap

This is the mistake everyone makes once.

When a policy rule matches `kinds: [Pod]`, Kyverno's autogen mechanism silently generates parallel rules for the Pod-owning controllers — `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob`, `ReplicaSet` — named by prefixing your rule name with `autogen-`. So a policy you wrote with one rule called `check-limits` is, at admission time, enforcing `check-limits` on bare Pods and `autogen-check-limits` on Deployments.

Your `kubectl apply` of a Deployment is therefore blocked by a rule called `autogen-check-limits`, not `check-limits`. An exception naming only `check-limits` waives nothing that was actually blocking you:

```yaml
  ruleNames:
    - check-limits           # covers bare Pods
    - autogen-check-limits   # covers Deployments, StatefulSets, Jobs, ...
```

You can see the generated names on the live policy:

```sh
kubectl get clusterpolicy require-resource-limits -o yaml | grep -A5 autogen
```

The second half of the trap is in `match.resources.kinds`: the resource the exception must match is whatever is being admitted. Blocking happens on the `Deployment` request, so the exception has to match `Deployment` — matching only `Pod` leaves the Deployment blocked. Listing both kinds, as in the example at the top, covers the controller and the Pods it spawns.

> [!WARNING]
> **Common pitfall**
>
> Matching `names: ["legacy-api"]` exactly. A Deployment named `legacy-api` creates Pods named `legacy-api-7c9f4b8d6-x2k9p` — hashes appended by the ReplicaSet. If your exception needs to cover the Pods as well as the controller, use a prefix wildcard: `names: ["legacy-api*"]`.

## What an exception looks like in a report

An exempted rule does not vanish from your reports. It changes result:

```sh
uid=$(kubectl get deployment legacy-api -n legacy-ns -o jsonpath='{.metadata.uid}')
kubectl get polr "$uid" -n legacy-ns -o yaml
```
```yaml
results:
  - policy: require-resource-limits
    rule: autogen-check-limits
    result: skip
    properties:
      exceptions: allow-legacy-api
      process: background scan
```

`result: skip` plus `properties.exceptions` naming the exception is the audit trail. Anyone reading this report can see which rule was waived, on which resource, and by which named object — and can go read that object's manifest in git. That is the entire argument for using exceptions instead of quietly widening a policy's `exclude` block: the exemption is a first-class thing with a name, a reviewer, and a diff.

This is also where Part 1's warning about the reports controller bites. If `--enablePolicyException=true` is set on the admission controller but not the reports controller, the Deployment is admitted and the report still says `fail`.

> [!TIP]
> **Try it — watch a result change from fail to skip**
>
> With an `Enforce` policy blocking `legacy-api` and exceptions enabled on both controllers:
>
> ```sh
> kubectl get polr -n legacy-ns -o wide
> kubectl apply -f allow-legacy-api.yaml
> sleep 20
> uid=$(kubectl get deployment legacy-api -n legacy-ns -o jsonpath='{.metadata.uid}')
> kubectl get polr "$uid" -n legacy-ns \
>   -o jsonpath='{range .results[*]}{.rule}{" -> "}{.result}{" ("}{.properties.exceptions}{")"}{"\n"}{end}'
> ```
>
> The rule that was reporting `fail` now reports `skip`, with the exception's name in parentheses.

## Self-check

1. Your exception object is in `platform-ns` and the workload is in `legacy-ns`. Does that work, and what decides it?
2. A Deployment is being blocked by a policy whose only rule is named `check-limits`. Which rule name or names must your exception list?
3. You wrote `policyName: require-resoruce-limits`. What error do you get?
4. Which field in a `PolicyReport` result tells you *which* exception excused a rule?

## Reference

- `kubectl explain policyexception.spec` — the full field list from the CRD on your cluster.
- `kubectl get policyexception -A` — every exception in the cluster; worth running before assuming a policy is simply not enforcing.
