# Configuring Metrics & Controlling Cardinality

Kyverno ships with some metric labels switched **off**. Scrape a stock install, look for `resource_namespace` on `kyverno_policy_results_total`, and it is not there — which is surprising the first time, because "which namespace is generating all these failures" is one of the first questions anyone asks.

That absence is deliberate, and understanding why is the core of this module. Every label value combination is a separate time series in Prometheus, and a label like `resource_namespace` multiplies the series count by the number of namespaces in your cluster. On a 600-namespace cluster that is the difference between a metric you can afford and one that quietly triples your monitoring bill.

This module covers the ConfigMap where those decisions live, how to turn a dimension back on when you need it, and how to use the resulting numbers.

## How this module is organised

1. **[Part 1 — The kyverno-metrics ConfigMap](./course-01-the-kyverno-metrics-configmap.md)** — `namespaces`, `metricsExposure`, `bucketBoundaries`: what each key does, the exact formats, and how to change them safely.
2. **[Part 2 — Using Metrics in Practice](./course-02-using-metrics-in-practice.md)** — the queries and alerts worth having, and diagnosing real incidents from the numbers.

## Learning objectives

After this module you can:

- Find the `kyverno-metrics` ConfigMap and read its three keys.
- Restrict metric collection to (or exclude it from) specific namespaces with the `namespaces` key.
- Read the default `metricsExposure` value and explain which label dimensions ship disabled and why.
- Re-enable a disabled label dimension for one metric, and explain the cardinality cost of doing so.
- Change histogram bucket boundaries and verify the new `le` values on the endpoint.
- Explain why a metrics configuration change needs a controller restart to be fully reflected.
- Write the handful of alerts that actually matter for a Kyverno installation.
- Diagnose "the cluster got slow after we rolled out policy" from metrics alone.

## Before you start

You should be able to scrape `/metrics` from inside the cluster and recognise the core metric families (Module 1). The linked lab gives you a kind cluster with Kyverno v1.13.2, two namespaces to treat differently, and a probe Pod for scraping.
