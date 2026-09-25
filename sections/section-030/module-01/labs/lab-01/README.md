# Kyverno Metrics Endpoint Sandbox

Welcome to the Module 1 targeted practice sandbox. A `metrics-probe` Pod is already running so you can scrape Kyverno's metrics endpoint from inside the cluster. You'll drive real traffic through an `Enforce` policy and then find that traffic in the numbers.

## Launching the Lab
Run the following command in your terminal to boot the kind Kubernetes cluster:
```bash
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-01/labs/lab-01
```
