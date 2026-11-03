# Summary

A good exception is narrow, owned and visible. Three tools narrow it, and a policy can keep the others honest.

## What you learned

A `conditions` block adds a test on the resource's content, such as a label, which tightening `match` cannot express. A `podSecurity` entry waives one Pod Security Standard control instead of a whole rule. `spec.background` on an exception controls whether it applies to background scans. Prefer an `exclude` block when a workload should never be in the policy's scope, and an exception when the policy applies and one case is allowed, with an owner and a reason.

Governance has two halves: RBAC decides who may create exceptions, and `--exceptionNamespace` decides where they count. A `ClusterPolicy` with `background: false` can validate `PolicyException` objects, for example requiring owner and expiry annotations. Kyverno does not interpret an expiry annotation on its own. To see what is exempted, read the `skip` results in reports, not only the exception objects; an exception that matches nothing exempts nothing.

The key facts to remember are these:

- `conditions` narrows by content, `match` narrows by identity.
- Use `podSecurity` to waive one control.
- Exceptions are policed by RBAC, the exception namespace and a validating policy.
- Audit from reports: the exceptions that matter are the ones that produced `skip`.

<!-- astrona:playground:destroy -->
