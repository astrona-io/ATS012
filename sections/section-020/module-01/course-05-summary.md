# Summary

A PolicyException lets one named workload skip one named rule, with a record you can audit. It does nothing until you switch the feature on.

## What you learned

On Kyverno v1.13 a `PolicyException` is a namespaced object in `kyverno.io/v2`. The feature is off by default: the object is stored but has no effect until `--enablePolicyException=true` is set, and `--exceptionNamespace` limits which namespace's exceptions are honoured. Set both on every controller that evaluates policy, at least the admission controller and the reports controller. With the flag on the admission controller only, the workload is admitted but background scans keep recording `fail` instead of `skip`.

An exception has `spec.exceptions[]` (policy name and rule names) and a `match` block (the resources). A Deployment is judged through its autogen rules, so the exception must name both the rule and its `autogen-` counterpart, and the `match` must cover the Pods the Deployment creates, for example with a name wildcard. The exemption shows in a report as `result: skip` with `properties.exceptions` naming the exception.

Selecting resources uses `match.any` and `match.all` with `kinds`, `names`, `selector`, `namespaces` and `namespaceSelector`; always set a namespace, because an exception only narrows a policy and never widens it. In Helm, `features.policyExceptions.enabled` and `features.policyExceptions.namespace` set both flags on every controller. When an exception does not apply, check the flags, the namespace, the policy and rule names, and the match in that order.

The key facts to remember are these:

- Feature flag and exception namespace are both required; the failure is silent.
- Name the rule and its autogen counterpart for Deployments.
- Match Pods, not only the Deployment, and use a wildcard for generated names.
- `skip` plus `properties.exceptions` is the audit trail.

<!-- astrona:playground:destroy -->
