# Part 2 — Governance, Alternatives & Auditing

> Prerequisite: [Part 1 — Narrowing an Exception](./course-01-conditions-podsecurity-and-background.md). Next: [Section 030 — Kyverno Metrics](../../section-030/README.md).

## Exception or `exclude`? A decision you should be able to defend

Both carve a hole. They differ in who owns the hole and where it is visible.

| | `exclude` block in the policy | `PolicyException` object |
| :--- | :--- | :--- |
| Lives in | The policy itself | Its own object, in the exception namespace |
| Changed by | Whoever can edit the policy | Whoever can create objects in the exception namespace |
| Visible as | A clause inside the enforcement document | A named object, listable with `kubectl get policyexception -A` |
| Shows in reports | Not at all — excluded resources produce no result | `result: skip` with `properties.exceptions` |
| Natural lifetime | Permanent | Temporary — you can grep for it, expire it, review it |

The rule of thumb that holds up in practice: **use `exclude` for what the policy permanently does not mean; use a `PolicyException` for what you are temporarily willing to tolerate.**

A policy that requires resource limits was never meant to apply to `kube-system` — that is not an exemption, that is the policy's actual scope, and it belongs in `exclude`. The same policy pointed at a legacy Deployment that your team has committed to fixing by Q3 *is* an exemption: it is a decision about one workload, it should have an owner and an end date, and it should be visible to anyone auditing the cluster without reading the enforcement policy line by line.

The failure mode of getting this backwards is quiet. A policy whose `exclude` block has accreted eleven workload names over two years no longer tells you anything about what the cluster enforces, and nothing in your reports will show you those eleven resources at all — they simply produce no results.

## Who is allowed to write one

`--exceptionNamespace` is a blunt but effective first control: exceptions only count if they live in one namespace you chose. Combine it with ordinary RBAC on that namespace and you have a workable model:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: exception-author
  namespace: platform-ns
rules:
  - apiGroups: ["kyverno.io"]
    resources: ["policyexceptions"]
    verbs: ["get", "list", "create", "update", "delete"]
```

Bind that Role to the small group you trust, and nobody else's `PolicyException` counts for anything, no matter where they create it. In a GitOps shop, go further: give the human group `get`/`list` only, grant `create` to the reconciler's service account alone, and every exemption arrives as a reviewed pull request.

> [!WARNING]
> **Common pitfall**
>
> Enabling `--enablePolicyException=true` without setting `--exceptionNamespace`. Exceptions are then honoured from every namespace in the cluster, which means anyone who can create objects in their own namespace can waive your rules for their own workloads. It works, the demos pass, and you have converted an enforcement boundary into an honour system.

## Policing exceptions with a policy

Kyverno can validate `PolicyException` objects like any other resource, which is how you enforce hygiene on exemptions themselves:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-exception-metadata
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-owner-and-expiry
      match:
        any:
          - resources:
              kinds:
                - PolicyException
      validate:
        message: "A PolicyException must carry 'exception.company.io/owner' and 'exception.company.io/expires' annotations."
        pattern:
          metadata:
            annotations:
              exception.company.io/owner: "?*"
              exception.company.io/expires: "?*"
```

Now an exception without a named owner and an expiry date cannot be created at all. Note `background: false` — this rule is about the shape of objects at creation time, and re-scanning existing exceptions hourly would tell you nothing new.

A natural companion is a `CleanupPolicy` that deletes exceptions whose `expires` annotation has passed, so an exemption granted "just for the migration" does not outlive the migration by two years. That belongs to the cleanup controller rather than this domain, but it is the other half of a working exception lifecycle and worth knowing exists.

## Auditing what is actually exempted

There are two questions, and they have different answers.

**"What exceptions exist?"** — read the objects:

```sh
kubectl get policyexception -A
kubectl get policyexception -n platform-ns -o yaml
```

**"What is actually being exempted right now?"** — read the reports. This is the better question, because it reflects reality rather than intent: an exception with a typo in `policyName` exists but exempts nothing, and this query will not show it.

```sh
kubectl get polr -A \
  -o jsonpath='{range .items[*]}{.scope.kind}{"/"}{.scope.name}{range .results[?(@.result=="skip")]}{"\t"}{.policy}{"/"}{.rule}{"\t"}{.properties.exceptions}{"\n"}{end}{end}'
```

Every line is one live exemption: the resource, the rule being waived, and the exception doing the waiving. That output is the artifact to bring to a compliance review — not a directory of YAML files that may or may not be having any effect.

> [!TIP]
> **Try it — find an exception that does nothing**
>
> Apply an exception with a deliberately misspelled `policyName`, then compare the two views:
>
> ```sh
> kubectl get policyexception -A                    # the broken exception is listed
> kubectl get polr -A -o jsonpath='{range .items[*]}{range .results[?(@.result=="skip")]}{.properties.exceptions}{"\n"}{end}{end}' | sort -u
> ```
>
> The object exists. No `skip` result names it. Nothing validates `policyName` against a real policy, so this is a silent, entirely normal failure mode — and the reports are where you catch it.

## Self-check

1. A policy should never apply to `kube-system`. `exclude` or `PolicyException`, and why?
2. You enabled exceptions cluster-wide without `--exceptionNamespace`. Describe the resulting security posture in one sentence.
3. Why does `kubectl get policyexception -A` overstate what is exempted?
4. What would a Kyverno policy over `PolicyException` resources typically require, and why should it be `background: false`?

## Reference

- [Kyverno docs — Policy Exceptions](https://kyverno.io/docs/exceptions/) — governance guidance and the CEL-based exception type used by the newer policy family.
- `kubectl get polr -A -o jsonpath=...` — the skip-result audit query above; worth keeping in a runbook.
