# Part 4 — Reviewing Exceptions at Scale

One exception is easy to understand. Fifty exceptions, written over two years by different teams, are not. A review process answers three questions: which exceptions exist, which of them still do something, and who owns them. This part shows how to answer each with `kubectl`.

## List every exception with its target

`PolicyException` objects are namespaced, so always search all namespaces. Use custom columns to see the policy each one targets:

```sh
kubectl get policyexception -A \
  -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,POLICY:.spec.exceptions[*].policyName,RULES:.spec.exceptions[*].ruleNames[*]
```

This gives one line per exception. Sort the output by policy name to see which policies have the most exceptions. A policy with many exceptions is a sign that the policy itself needs a change.

## Show the owner and the reason

If a governance policy requires `owner` and `reason` annotations, print them as columns too:

```sh
kubectl get policyexception -A \
  -o custom-columns=NAME:.metadata.name,OWNER:.metadata.annotations.owner,REASON:.metadata.annotations.reason
```

An empty value in a column is an exception that was created before the governance policy. List these first, because nobody can say why they exist.

## Find exceptions that exempt nothing

An exception is dead if no resource uses it. Kyverno records the exceptions that applied in the `properties.exceptions` field of a report result. List the results that carry that property:

```sh
kubectl get polr -A -o jsonpath='{range .items[*].results[?(@.result=="skip")]}{.policy}{" "}{.rule}{" "}{.properties.exceptions}{"\n"}{end}'
```

Compare this list with the exception list. An exception whose name never appears here exempted no resource in the last scan, so it is a candidate for deletion. Check the full report, because a rule that is skipped for another reason also produces `skip`.

## Review on a schedule

Write the review into the team calendar, not into the exception itself. At each review, for every exception, decide one of three things: delete it because the workload was fixed, renew it with a new date, or convert it into a change of the policy because many workloads need it.

When you remove an exception, delete the object, then check the next background scan. The result for the workload goes back to `fail`. If the workload was not fixed, you need to know before the scan does.

> [!TIP]
> **Try it - find a dead exception**
>
> Create two exceptions, one that matches a running workload and one whose `match` names a Pod that does not exist. Wait for the next background scan, then run the `skip` query above. Only the first exception name appears.

## Common pitfalls

- Reviewing the exception objects only. They show intent, not effect.
- Deleting an exception and not checking the report. The workload may start to fail on its next rollout.
- Counting `skip` results as proof that an exception works. A `skip` can also come from a failed precondition. Check `properties.exceptions`.
- Treating a long list of exceptions for one policy as normal. It is a signal to change the policy.

## Where this leaves you

You can list, attribute and test exceptions with `kubectl`, and you know the three outcomes of a review. The last module of this section adds a deadline to every exception, so that part of the review happens automatically.
