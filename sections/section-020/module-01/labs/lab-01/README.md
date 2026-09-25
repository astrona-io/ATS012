# PolicyException Sandbox

Welcome to the Module 1 targeted practice sandbox. A legacy Deployment is running without resource limits. You'll put an `Enforce` policy in front of it, watch new violators get blocked, then carve out an auditable exemption for exactly that one workload — and prove it in the reports.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-01/labs/lab-01
```
