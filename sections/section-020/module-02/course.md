# Narrowing, Governing & Auditing Exceptions

An exception that works is easy. An exception you can defend in a review six months later is harder, and that is what this module is about.

Module 1 gave you an object that waives a rule for a set of named resources. That is often too blunt: "every Pod whose name starts with `legacy-api`" will happily cover a brand-new workload somebody names `legacy-api-v2` next quarter. This module covers the fields that narrow an exception to the case you actually meant, and then the organisational question nobody's YAML answers for you — who is allowed to create these things, and how would you know if someone did?

## How this module is organised

1. **[Part 1 — Narrowing an Exception: conditions, podSecurity & background](./course-01-conditions-podsecurity-and-background.md)** — the fields that turn "these names" into "these resources, in this state, for this control".
2. **[Part 2 — Governance, Alternatives & Auditing](./course-02-governance-and-alternatives.md)** — exception versus `exclude`, controlling who can create one, policing exceptions with a policy, and auditing the ones that exist.

## Learning objectives

After this module you can:

- Add a `conditions` block to an exception and explain how it differs from tightening `match`.
- Write a `podSecurity` exemption that waives one named Pod Security Standard control rather than a whole rule.
- Explain what `spec.background` on an exception controls.
- Choose correctly between a `PolicyException` and an `exclude` block in the policy, and justify the choice.
- Describe the RBAC posture that makes exceptions safe, and why `--exceptionNamespace` is the other half of it.
- Write a Kyverno policy that validates PolicyExceptions themselves — for example requiring an expiry annotation and an owner.
- Audit every active exemption in a cluster from the reports, not from the exception objects.

## Before you start

You should have completed Module 1 and have a working exception — feature flags set, rule waived, report showing `skip`. The linked lab starts from roughly that state and asks you to make the exemption dramatically narrower, and then to stop anyone from writing a sloppy one.
