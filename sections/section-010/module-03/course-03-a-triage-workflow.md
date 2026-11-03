# Part 3 — A Triage Workflow

A report shows every finding with equal weight. Triage is the step that sorts them into an order of work. This part gives a repeatable sequence: group findings, rank them by severity, assign them to an owner, and decide which findings to fix and which to exempt.

## Group before you read

Reading findings one at a time hides the pattern. A single policy that fails on two hundred Pods is one problem with one fix, not two hundred problems. Start by counting failures per policy with `jq`:

<!-- astrona:playground:renew -->

```sh
kubectl get polr -A -o json | jq -r '[.items[].results[] | select(.result=="fail")] | group_by(.policy) | .[] | "\(length)\t\(.[0].policy)"'
```

The expression keeps the failing results, groups them by policy name, and prints a count and a name for each group. Sort the output with `sort -rn` to put the largest group first.

## Rank by severity

Within the groups, severity tells you which policy to open first. The `severity` field is on every result that comes from a policy with the `policies.kyverno.io/severity` annotation. The report schema allows the values `critical`, `high`, `medium`, `low` and `info`. A result from a policy without the annotation has no `severity` field, so it sorts last in any severity count.

```sh
kubectl get polr -A -o json | jq -r '[.items[].results[] | select(.result=="fail")] | group_by(.severity) | .[] | "\(length)\t\(.[0].severity // "none")"'
```

Work through `critical` and `high` first. A large group of `low` findings is real work, and a small group of `critical` findings usually comes before it.

## Find the owner

A finding that has no owner is not fixed. Reports carry the namespace and the resource name, so use the namespace as the route to a team. A convention such as a `team` or `owner` label on each namespace lets a script look the owner up:

```sh
kubectl get ns -L team
```

The `-L` flag adds a column with the value of the label. A namespace with an empty value is a finding of its own: nobody is responsible for it.

## Decide: fix, exempt or change the policy

Each group of findings ends in one of three decisions.

1. Fix the resource, when the policy is right and the workload is wrong.
2. Exempt the resource with a `PolicyException`, when the workload has a documented reason to differ. The exception then makes the result `skip`, and the finding leaves the `fail` count.
3. Change the policy, when many correct workloads fail. A rule that fails on most of the cluster is usually a rule that is too strict or poorly written.

Write the decision down next to the policy name. A finding with no decision comes back at the next review.

## Re-check after the change

After you fix resources, wait for the report to refresh and run the same group-by command again. The count for the policy must fall. If it does not, either the report has not been updated yet, or the fix did not satisfy the rule, and the `message` on the result tells you which condition still fails.

> [!TIP]
> **Try it**
>
> Run both group-by commands against the playground. Pick the policy with the highest severity and fix one workload that fails it. Run the first command again after a minute and confirm that its count fell by one.

You can now turn a flat list of findings into a ranked list of work with owners and decisions.

## Common pitfalls

> [!WARNING]
> - Ranking by count only. A single `critical` finding can matter more than a hundred `low` ones.
> - Treating a missing `severity` as `low`. Policies without the annotation are unranked, and the missing annotation is something to fix in the policy.
> - Exempting a finding to make a dashboard green without recording why. An exemption is a decision, and it needs an owner and a reason.
