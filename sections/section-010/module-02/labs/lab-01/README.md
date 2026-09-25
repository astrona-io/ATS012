# Reports Pipeline Tuning Sandbox

Welcome to the Module 2 targeted practice sandbox. Two namespaces already hold policy-violating Deployments that were created *before* any policy existed. In this lab you'll make one of them show up in a `PolicyReport` on a schedule you choose, and keep the other one out of reporting entirely.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-02/labs/lab-01
```
