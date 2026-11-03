# Part 3 — Querying Reports with kubectl

A cluster with a few hundred workloads produces a few hundred reports. Reading them one by one with `-o yaml` does not scale, so this part shows how to ask a report question and get only the answer: which resources fail, under which policy, and with which message.

The examples use the `platform-ns` namespace from the playground, where `violator-pod` breaks two policies and `compliant-pod` breaks none.

## Start with the printer columns

`kubectl get` prints a summary table for reports without any extra flags. The table is built from the report's `summary` field and from `scope`, so it is the cheapest way to find which resources have findings.

<!-- astrona:playground:renew -->

```sh
kubectl get polr -A
kubectl get cpolr
```

Read the `FAIL`, `WARN` and `ERROR` columns first. A row with a non-zero value in any of them needs a closer look. A row with only `PASS` and `SKIP` values needs none.

## Use labels to find a report from a resource

Kyverno labels each per-resource report so you can select it without computing a UID. List the labels on your reports first, so you use the exact label keys your Kyverno version writes:

```sh
kubectl get polr -n platform-ns --show-labels
```

You can then pass any of those labels to `-l`. For example, `-l app.kubernetes.io/managed-by=kyverno` selects every report Kyverno manages, which separates them from reports written by other tools that use the same API group.

## Extract fields with custom-columns

`-o custom-columns` builds your own table from any field. It works well for a flat view of the report summary:

```sh
kubectl get polr -A -o custom-columns='NS:.metadata.namespace,KIND:.scope.kind,NAME:.scope.name,FAIL:.summary.fail,WARN:.summary.warn'
```

The part before each colon is the column header. The part after it is a path into the object.

## Filter results with jsonpath

The `results` field is a list, so to look inside it you need a filter. A jsonpath filter expression has the form `[?(@.field=="value")]`, and `@` means the current list item.

```sh
kubectl get polr -n platform-ns -o jsonpath='{range .items[*].results[?(@.result=="fail")]}{.policy}{"\t"}{.rule}{"\t"}{.message}{"\n"}{end}'
```

This prints one line for every failing result in the namespace, with the policy, the rule and the message separated by tabs. Change `"fail"` to `"warn"`, `"error"` or `"skip"` to inspect the other result values.

Jsonpath cannot combine conditions across different fields in one list item as easily as a real query language can. When you need two conditions, or a count, use `-o json` and pipe the output to `jq`, which the next part covers.

## Ask the schema, not the documentation

The CRD installed in your cluster is the authority on which fields exist. `kubectl explain` reads it directly:

```sh
kubectl explain policyreport.results
kubectl explain policyreport.summary
```

If a field you saw in an example does not appear in `kubectl explain`, your cluster does not have it, and a query that uses it returns nothing.

> [!TIP]
> **Try it**
>
> List the failing results in `platform-ns` with the jsonpath command above. Then change the filter to `warn` and compare the two lists. The policy that is annotated `policies.kyverno.io/scored: "false"` appears only in the second list.

You can now list reports, select them by label, and pull out exactly the results you need. The remaining question is how to turn these queries into something a script or a pipeline can act on.

## Common pitfalls

> [!WARNING]
> - Quoting. A jsonpath expression in single quotes must use double quotes for string comparisons, as in `@.result=="fail"`. Mixing the two quote styles produces an empty result, not an error.
> - An empty output does not prove there are no findings. Check that you used `-A` or the right namespace, and that you also queried `cpolr` for cluster-scoped resources.
> - Reports are updated as the cluster changes, so a result you saw a minute ago may be gone. Query again before you draw conclusions.
