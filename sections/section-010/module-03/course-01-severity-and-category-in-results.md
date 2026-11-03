# Part 1 — Severity and Category in Results

> Prerequisite: [Module 2 — The Reports Pipeline & Its Tuning](../module-02/course.md). Next: [Part 2 — Report Lifecycle and the Tool Ecosystem](./course-02-report-lifecycle-and-tooling.md).

A failing result tells you that a rule was broken. It does not tell you whether to wake someone up. That judgement belongs to the policy author, who records it in two annotations on the policy.

## The two annotations

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
  annotations:
    policies.kyverno.io/severity: high
    policies.kyverno.io/category: Best Practices
```

- `policies.kyverno.io/severity` is a free-form string. The Kyverno sample policies use `low`, `medium` and `high`. Pick one scale for your organisation and keep to it, because a typo such as `High` is a different value to a filter.
- `policies.kyverno.io/category` groups policies by theme, for example `Best Practices` or `Pod Security Standards (Baseline)`.

Both are labels for people and tools. Neither one changes whether a request is admitted or what the result is. Only `validationFailureAction` decides blocking, and only `policies.kyverno.io/scored` decides whether a failure is reported as `fail` or `warn`.

## Where they land

Each rule evaluation that produces a result copies the policy's two annotations into that result entry:

```yaml
results:
  - policy: require-resource-limits
    rule: check-limits
    result: fail
    severity: high
    category: Best Practices
    message: "Every container must set resources.limits.cpu and resources.limits.memory."
```

The severity belongs to the **policy**, not to the rule. A policy with three rules gives all three the same severity. If two rules deserve different severities, put them in two policies.

> [!WARNING]
> **Common pitfall**
>
> Editing the annotation and expecting the existing results to change at once. A result is rewritten when its resource is evaluated again: on the next admission request for that resource or on the next background scan. Until then the old value stays in the report.

## Counting across namespaces

`kubectl get polr -A` returns every namespaced report. A jsonpath filter inside `range` selects only the results you want:

```sh
kubectl get polr -A -o jsonpath='{range .items[*].results[?(@.severity=="high")]}{.policy}{"\t"}{.result}{"\n"}{end}'
```

Pipe the output through `grep -c '^...'` or `sort | uniq -c` to count it. To count only failures of one severity, print `.result` and count the `fail` lines:

```sh
kubectl get polr -A -o jsonpath='{range .items[*].results[?(@.severity=="high")]}{.result}{"\n"}{end}' | grep -c '^fail$'
```

For a table with one row per report, use custom columns on the `summary`:

```sh
kubectl get polr -A -o custom-columns=NS:.metadata.namespace,KIND:.scope.kind,NAME:.scope.name,FAIL:.summary.fail,WARN:.summary.warn
```

### Do not forget the cluster-scoped half

`PolicyReport` objects cover namespaced resources. A finding on a namespace, a node or a persistent volume lives in a `ClusterPolicyReport`. A count that reads only `polr` misses it, so read both:

```sh
kubectl get cpolr -o jsonpath='{range .items[*].results[?(@.severity=="high")]}{.result}{"\n"}{end}'
```

> [!TIP]
> **Try it — severity per policy**
>
> In your playground, run the first jsonpath query above for `high`, then for `medium`. Which policy produces each? Then create a Pod without a `team` label in `team-red` and re-run the `medium` query once the scan has finished. How did the count change?

## Self-check

1. Which object carries the severity annotation, the policy or the rule?
2. A policy has `severity: critical` and `scored: "false"`. What `result` do its failures have, and what `severity`?
3. Why does a namespace-by-namespace count of `polr` sometimes understate the findings?

## Reference

- [Kyverno docs — Policy Reports](https://kyverno.io/docs/policy-reports/)
- [Kubernetes — JSONPath support](https://kubernetes.io/docs/reference/kubectl/jsonpath/)
