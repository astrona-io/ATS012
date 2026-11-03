---
estimated_duration: 25m
---

# Read The Counters, Write The Alert

Graded lab for the module on querying metrics and writing alert rules. You generate admitted and rejected requests, read the matching counters from the endpoint, record them, and write the alert you would put on the failure counter. The task is in `question.md`; the walkthrough is in `solution.md`.

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

## Launching the Lab

```bash
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-03/labs/lab-01
```
