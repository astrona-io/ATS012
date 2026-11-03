---
estimated_duration: 20m
---

# Triage Reports By Severity

Graded lab for the module on severity, categories and consuming reports. Two annotated `Audit` policies judge three Pods across two team namespaces. You read the severity and category on the results, watch a report leave with its resource, and record a count per severity. The task is in `question.md`; the walkthrough is in `solution.md`.

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

## Launching the Lab

```bash
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-03/labs/lab-01
```
