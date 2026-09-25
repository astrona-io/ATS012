# Part 2 — Reading Results: the Five Result Types

> Prerequisite: [Part 1 — PolicyReport and ClusterPolicyReport](./course-01-policyreport-and-clusterpolicyreport.md). Next: [Module 2 — The Reports Pipeline & Its Tuning](../module-02/course.md).

Every entry in `results[]` carries exactly one `result` value, and there are only five. Knowing which condition produces which value is the difference between "the report says `skip`, so the policy is broken" and "the report says `skip`, so a precondition correctly excluded this resource".

## The five values

| `result` | What actually happened |
| :--- | :--- |
| `pass` | The rule matched the resource and the resource satisfied it. |
| `fail` | The rule matched the resource and the resource violated it. |
| `warn` | Same as `fail`, except the policy is annotated `policies.kyverno.io/scored: "false"`, which downgrades every failure it produces from `fail` to `warn`. |
| `error` | The rule could not be evaluated — most commonly a variable substitution failure outside a precondition, such as `{{ request.object.metadata.labels.team }}` on a resource with no labels at all. |
| `skip` | The rule was deliberately not applied: a precondition evaluated false, a matching `PolicyException` exempted the resource, or a conditional anchor's condition was not met. |

Two of these deserve more than a table row.

### `warn` is a policy-author decision, not a severity

`warn` is not "a small failure". It appears only because someone annotated the policy:

```yaml
metadata:
  name: require-team-label
  annotations:
    policies.kyverno.io/scored: "false"
```

`scored: "false"` means "count this policy's findings as informational". Every failure it produces lands in the report as `warn` instead of `fail`, and the `summary.fail` counter stays at zero while `summary.warn` climbs. Teams use it for advisory policies that should show up on a dashboard without tripping a "this namespace has failures" alert.

The trap: if you gate a CI check on `summary.fail == 0`, an advisory policy annotated `scored: "false"` will never trip it, no matter how many resources violate it. That is the intended behaviour — just make sure it is the behaviour you meant.

### `skip` means "correctly not applied", and it is your exception audit trail

A `skip` entry is a positive statement: Kyverno considered this resource, then declined to judge it, and here is the rule it declined on. This is exactly what you want from an exemption system — the resource does not silently vanish from reporting, it shows up as explicitly excused.

When the cause is a `PolicyException` (Section 020), the result entry also carries a `properties.exceptions` field naming the exception that applied:

```yaml
results:
  - policy: disallow-host-namespaces
    rule: host-namespaces
    result: skip
    properties:
      exceptions: delta-exception
      process: background scan
```

That field is the difference between an audit you can defend and a shrug. Anyone reading the report can see *which* exception excused *which* rule on *which* resource.

> [!WARNING]
> **Common pitfall**
>
> Reading `skip` as "the rule did not match this resource". A rule that does not match a resource produces **no result entry at all** — the resource simply never appears for that rule. `skip` means the rule *did* match and was then deliberately not enforced. If you see `skip` where you expected `fail`, look for a precondition or a `PolicyException`, not for a broken `match` block.

## Querying without reading YAML

Reports are objects, so all the normal `kubectl` output machinery works on them. The queries below are the ones worth memorising.

**Every report in the cluster, with its counters:**

```sh
kubectl get polr -A -o wide
kubectl get cpolr -o wide
```

**Only the failing entries in one report:**

```sh
kubectl get polr "$uid" -n platform-ns \
  -o jsonpath='{range .results[?(@.result=="fail")]}{.policy}{"/"}{.rule}{"\t"}{.message}{"\n"}{end}'
```

The `[?(@.result=="fail")]` filter is a jsonpath predicate: it walks `results[]` and keeps only entries whose `result` field equals `fail`. Swap `"fail"` for `"skip"` to audit exemptions, or `"error"` to find broken variable references.

**Everything failing anywhere, one line per finding:**

```sh
kubectl get polr -A \
  -o jsonpath='{range .items[*]}{.scope.kind}{"/"}{.scope.name}{range .results[?(@.result=="fail")]}{"\t"}{.policy}{"/"}{.rule}{"\n"}{end}{end}'
```

**Which policies are producing findings at all, sorted by volume** — useful when you have just turned on a policy set and want to know what is noisiest:

```sh
kubectl get polr -A -o json \
  | grep -o '"policy":"[^"]*"' | sort | uniq -c | sort -rn
```

> [!TIP]
> **Try it — separate the failures from the passes**
>
> With an `Audit` policy live and `legacy-api` violating it:
>
> ```sh
> uid=$(kubectl get deployment legacy-api -n platform-ns -o jsonpath='{.metadata.uid}')
> kubectl get polr "$uid" -n platform-ns -o jsonpath='{.summary}{"\n"}'
> kubectl get polr "$uid" -n platform-ns \
>   -o jsonpath='{range .results[?(@.result=="fail")]}{.rule}{": "}{.message}{"\n"}{end}'
> ```
>
> Expect the summary to show `{"error":0,"fail":1,"pass":0,"skip":0,"warn":0}` and the second command to print the rule name followed by the exact `validate.message` string the policy author wrote. That message is the whole reason to write a good one: it is what the person reading the report at 2am actually sees.

## Self-check

1. A `ClusterPolicy` evaluates `Namespace` objects and finds a violation. Which report kind holds the finding, and in which namespace?
2. `summary.fail` is `0` but your dashboard shows twelve violations. What annotation should you look for on the policy?
3. A result entry shows `result: error`. Is the resource compliant, non-compliant, or neither?
4. What is the difference in a report between a rule that did not match a resource and a rule that was skipped?

## Reference

- `kubectl explain policyreport.results.result` — the enum, direct from the CRD.
- [Kyverno docs — Policy Reports](https://kyverno.io/docs/policy-reports/) — including the full table of conditions producing each result type.
