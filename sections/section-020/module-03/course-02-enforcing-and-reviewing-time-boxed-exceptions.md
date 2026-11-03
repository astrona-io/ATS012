# Part 2 — Enforcing and Reviewing Time-Boxed Exceptions

A label that people may forget is a suggestion. This part turns it into a rule, and then covers what happens around the edges: renewal, review and what the reports show when the exception ends.

## A policy that requires the ttl

Kyverno can validate its own exceptions. This policy rejects any `PolicyException` that has no ttl label or an empty one:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-exception-ttl
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-ttl
      match:
        any:
        - resources:
            kinds:
              - PolicyException
      validate:
        message: "A PolicyException must carry the label cleanup.kyverno.io/ttl so that it expires."
        pattern:
          metadata:
            labels:
              cleanup.kyverno.io/ttl: "?*"
```

Points to notice:

- **`background: false`.** The rule exists to block creation. Scanning old exceptions for the label would be a different, reporting job.
- **`?*` means "at least one character".** The label must exist and not be empty.
- **Rule matching on `PolicyException`.** Policies can match Kyverno's own kinds as well as core ones, which is also how Module 2's owner-and-expiry policy works.
- **Existing exceptions are untouched.** Admission policies judge new and changed objects. Exceptions created before the policy need to be re-applied with a ttl, or deleted.

You can tighten the pattern further, for example by using an operator to reject values longer than a threshold, but a first version that simply requires the label is already a large improvement.

## Renewal without drift

Expiry needs a counterpart, or people will learn to re-create exceptions the minute they vanish. A workable process:

1. The exception carries owner and ticket annotations (Module 2). The ticket is where the decision to extend is made.
2. An extension is a **new** exception object, created by the same pipeline that created the first one, with a fresh ttl and a reference to the same ticket.
3. A weekly review lists live exceptions with their ttl and owner and asks of each: is it still needed?

Because the ttl counts from creation, you cannot extend by editing the label on an existing object. Re-applying the manifest does not reset the creation time either. Deleting and re-creating is what renewal means.

## What expiry looks like in the reports

Before the expiry, the exempt workload shows result `skip` for the waived rule. When the controller deletes the exception:

- New admissions of matching Pods are judged normally. Without limits, they are blocked by the Enforce policy.
- The next background scan of the existing Pods produces `fail` for the rule that used to be waived.

So the end of an exception is visible in the same place as its start. A dashboard that counts `skip` results by policy shows the exemption footprint shrinking when exceptions expire, and a `fail` appearing where a `skip` was is the signal that a team never fixed the underlying problem.

## Pitfalls

- **Ttl without RBAC.** Nothing is deleted, no error is raised.
- **Annotation instead of label.** Ignored.
- **Very long ttl.** `8760h` is a year; you have rebuilt the problem you set out to solve.
- **Expecting a rollback.** The Pods admitted during the exception stay running. Plan the fix, not only the expiry.
- **Naming only the base rule.** Pods created by a Deployment are judged by the autogen rule, so list both `check-limits` and `autogen-check-limits` in `ruleNames`.

## Try it

Apply `require-exception-ttl`, then try to create an exception without the label and read the rejection message. Add the label and try again. Finally, list exceptions with their ttl in one command:

```bash
kubectl get policyexception -A -L cleanup.kyverno.io/ttl
```

Next: [Summary](./course-03-summary.md)
