# Summary

Kyverno records what it finds in two report kinds. The kind follows the scope of the reported resource, never the policy.

## What you learned

`PolicyReport` (`polr`) holds findings for namespaced resources and lives in the resource's namespace. `ClusterPolicyReport` (`cpolr`) holds findings for cluster-scoped resources such as namespaces and volumes. Modern Kyverno stores one report per resource, named after the resource's `metadata.uid` and owned by it, so the report is garbage-collected when the resource is deleted. Find a report from the `KIND` and `NAME` columns or from the UID, never by guessing a name.

A report has a `scope` (the resource), a `results[]` list (one entry per rule per resource) and a `summary` (counts). Each result is exactly one of five values: `pass`, `fail`, `warn`, `error` or `skip`. `warn` appears only when the policy carries `policies.kyverno.io/scored: "false"`, so a gate written on `summary.fail` never sees advisory policies. `error` means the rule could not be evaluated. `skip` means the rule matched and was deliberately not applied, for example because of a failed precondition or a `PolicyException`; a rule that did not match leaves no entry at all.

The key facts to remember are these:

- Report kind follows the reported resource's scope.
- Report name is the resource UID, and the report is owned by that resource.
- `warn` means advisory (`scored: "false"`), not a mild failure.
- `skip` is a matched rule that was not applied; no match means no entry.
- Use a jsonpath filter to pull only the results you need.

<!-- astrona:playground:destroy -->
