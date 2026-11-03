# Part 2 — Report Lifecycle and the Tool Ecosystem

> Prerequisite: [Part 1 — Severity and Category in Results](./course-01-severity-and-category-in-results.md).

A report is not a log. It is the current state of one resource judged by the policies in force. Understanding when it changes and when it disappears is what lets you trust a count.

## What removes a report or a result

| What you do | What happens to the reports |
| :--- | :--- |
| Delete the resource | The report is owned by the resource, so Kubernetes garbage-collects it. |
| Delete a policy | The policy's results leave the remaining reports when the reports controller reconciles. |
| Change a policy | Results are recomputed on the next admission request or background scan for each resource. |
| Fix the resource | The next evaluation replaces `fail` with `pass`. The history is not kept. |

A report keeps no history. If you need "how many failures last Tuesday", something outside Kyverno has to record it: a metric, an exporter or a tool that stores snapshots.

> [!WARNING]
> **Common pitfall**
>
> Treating a falling failure count as proof that people fixed things. A policy that was deleted, a namespace that was excluded or a background scan that stopped all make the count fall too. Check that the policy is still there and that scans are running before you celebrate.

## What Enforce leaves out

A request that an `Enforce` policy rejects never creates the resource, so there is no resource to own a report and no report entry for it. The rejection is visible in the client's error message and in the admission metrics you meet in Section 030. Reports describe what exists. This is why an audit that uses only reports cannot see blocked attempts.

## Report volume

Because a report exists per resource, a large cluster holds many report objects, each one stored in etcd. Two things keep this manageable: the reports controller flags you met in Module 2, and writing policies that match only the kinds you need. A policy matching `*` produces results for everything.

## Tools that read reports

The `wgpolicyk8s.io` report format is a shared, open format, and several tools read it. **Policy Reporter** is a separate open-source project, installed separately from Kyverno, that watches `PolicyReport` and `ClusterPolicyReport` objects and offers a web UI, Prometheus metrics derived from the reports, and notification targets for chat and logging systems. Consult its own documentation for installation and options; it is not part of the Kyverno install and this course does not run it.

Whatever tool you use, it reads the same objects you read with `kubectl`. It does not know more than the report knows, so everything in Module 1 still applies: `warn` means an advisory policy, `skip` means a matched rule that was not applied, and a missing entry may mean the rule never matched.

A CI gate is the simplest consumer of all. A pipeline step can run the severity count from Part 1 and fail the build when `high` failures exist.

> [!TIP]
> **Try it — a report leaves with its resource**
>
> In your playground, list the reports in `team-red`, delete the Pod `red-bad` and list them again. Then delete the policy `require-team-label` and compare the results in `blue-bad`'s report before and after. How long did each change take?

## Self-check

1. Why does a rejected `Enforce` request leave nothing in the reports?
2. A report has `fail: 0` after you deleted the policy. Is the workload compliant?
3. A dashboard shows a result you do not understand. Where is the authoritative record, and what does the tool add to it?

## Reference

- [Kyverno docs — Policy Reports](https://kyverno.io/docs/policy-reports/)
- [Policy Reporter project](https://github.com/kyverno/policy-reporter)
