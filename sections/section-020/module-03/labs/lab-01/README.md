---
estimated_duration: 20m
---

# Time-Box A PolicyException

Graded lab for the module on time-boxed exceptions and cleanup. You let the cleanup controller delete exceptions, require a ttl label on every exception with a policy, and create an exception that ends after eight hours. The task is in `question.md`; the walkthrough is in `solution.md`.

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

## Launching the Lab

```bash
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-03/labs/lab-01
```

When you think you have finished, send it for grading:

```bash
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-03/labs/lab-01
```
