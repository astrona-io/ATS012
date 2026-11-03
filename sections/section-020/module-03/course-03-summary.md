# Summary

An exception that never ends is a hole in the policy. The cleanup controller can make it end.

## What you learned

Kyverno has no built-in expiry for a `PolicyException`, and it does not read an expiry annotation. The cleanup controller deletes any resource that carries the label `cleanup.kyverno.io/ttl`, so putting that label on an exception time-boxes it. The value is a duration such as `2h` or an absolute time, counted from the creation of the object. The cleanup controller can only delete what RBAC lets it delete: grant it `get`, `list`, `watch` and `delete` on `policyexceptions` with a ClusterRole labelled `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"`. Without that role the label does nothing and the exception stays.

A policy can then make the label mandatory, so every exception has an end. After the exception is deleted, the next admission is judged by the policy again and the next background scan records `fail` again, so the workload must be fixed or the exception renewed before expiry.

The key facts to remember are these:

- Expiry is a label handled by the cleanup controller, not an annotation.
- Grant delete rights with an aggregated ClusterRole, or nothing is deleted.
- Enforce the label with a validating policy on `PolicyException`.
- Plan the fix before the exception disappears.

<!-- astrona:playground:destroy -->
