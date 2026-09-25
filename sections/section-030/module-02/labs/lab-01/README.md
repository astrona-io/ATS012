# Metrics Configuration Sandbox

Welcome to the Module 2 targeted practice sandbox. Kyverno ships with some metric labels deliberately switched off and a fifteen-bucket histogram. In this lab you'll change all three `kyverno-metrics` ConfigMap keys and prove each change on the raw endpoint.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-02/labs/lab-01
```
