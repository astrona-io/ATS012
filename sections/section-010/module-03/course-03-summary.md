# Summary

A report is a database you can query. Severity and category annotations make it sortable, and ownership makes it self-cleaning.

## What you learned

Kyverno copies the policy annotations `policies.kyverno.io/severity` and `policies.kyverno.io/category` into each result of a report, so you can count findings by severity across every namespace with one jsonpath filter. The annotation is a label for people and tools; it does not change whether a request is admitted. A report is owned by the resource it describes, so deleting the resource removes its report, and deleting a policy removes that policy's results from the remaining reports on the next reconcile. Cluster-scoped resources report into the `ClusterPolicyReport`, so a namespace-by-namespace count misses them.

Policy Reporter is a separate open-source project that reads these reports and adds a UI, metrics and notification targets. It reads the same objects you read with `kubectl`, so the rules about `warn` and `skip` apply to it as well.

The key facts to remember are these:

- Severity and category come from policy annotations and appear on each result.
- Count across namespaces with `kubectl get polr -A` and add `cpolr` for cluster-scoped findings.
- Deleting a resource deletes its report; deleting a policy removes its results.
- A tool that shows reports does not change what a report means.

<!-- astrona:playground:destroy -->
