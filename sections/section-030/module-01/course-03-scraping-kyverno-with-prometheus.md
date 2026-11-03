# Scraping Kyverno with Prometheus

Reading the endpoint with `curl` shows what Kyverno exposes, but nobody watches a cluster that way. A monitoring system has to collect the metrics on a schedule and store them. This chapter covers how Prometheus finds the four Kyverno metrics endpoints, and how to confirm it is actually collecting them.

## What Prometheus needs to know

Prometheus (an open source monitoring system that stores metrics as time series) pulls data. It sends an HTTP GET request to each target's `/metrics` path at a fixed scrape interval, then stores every sample with a timestamp. A target is one endpoint, such as one Pod IP and port.

For Kyverno, Prometheus needs four things: the namespace (`kyverno`), the Services or Pods to scrape, the port name or number (`8000`), and the path (`/metrics`, the default). You can give it these with a static `scrape_configs` entry, with Kubernetes service discovery, or with the Prometheus Operator.

## Using a ServiceMonitor

The Prometheus Operator is a separate project that adds Custom Resource Definitions to the cluster. A `ServiceMonitor` is one of them. It selects Services by label and tells the Operator which port to scrape. The Kyverno Helm chart can create these objects for you:

```sh
helm upgrade kyverno kyverno/kyverno -n kyverno --reuse-values \
  --set admissionController.serviceMonitor.enabled=true \
  --set backgroundController.serviceMonitor.enabled=true \
  --set cleanupController.serviceMonitor.enabled=true \
  --set reportsController.serviceMonitor.enabled=true
```

This only works when the `ServiceMonitor` CRD is already installed. Without the Operator, the Helm render fails or the object is rejected by the API server.

The Operator then needs a Prometheus instance whose `serviceMonitorSelector` matches the labels on the `ServiceMonitor`. This is a common source of silent failure: the object exists, but no Prometheus selects it.

## Checking that the targets are up

Prometheus records a synthetic metric named `up` for every target. The value is `1` when the last scrape succeeded and `0` when it failed. Query it by job or namespace:

```promql
up{namespace="kyverno"}
```

A healthy installation returns one series per controller Pod. Replicas count separately, so three admission controller replicas give three series. A missing series means Prometheus never discovered the target. A series with value `0` means it found the target but the scrape failed.

The scrape duration is also recorded in `scrape_duration_seconds`. A very long duration on a Kyverno target usually means the endpoint returns a large number of series.

## Which controller to scrape for which question

All four controllers expose metrics, and the same metric name can appear on more than one. Scrape all four, and filter by the `job` or `service` label in queries. As a rule:

- Admission requests, admission review latency and policy execution time come from the admission controller.
- Background scan and mutate-existing results come from the background controller and the reports controller.
- Cleanup deletions come from the cleanup controller.

> [!TIP]
> **Try it - confirm the metrics Services have endpoints**
>
> ```sh
> kubectl -n kyverno get svc | grep metrics
> kubectl -n kyverno get endpoints
> kubectl get crd servicemonitors.monitoring.coreos.com
> ```
>
> The first two commands show whether each metrics Service has Pod addresses behind it. The third fails with `NotFound` when the Prometheus Operator is not installed, which is the case in the playground. That tells you a `ServiceMonitor` cannot be created there.

## Common pitfalls

- Enabling `serviceMonitor` in Helm values on a cluster without the Operator CRDs.
- Creating a `ServiceMonitor` whose labels do not match the Prometheus `serviceMonitorSelector`, so nothing is scraped and nothing reports an error.
- Scraping only the admission controller and then wondering why background scan metrics are missing.
- Reading a count from one replica and treating it as the cluster total. Sum across replicas with `sum`.

## What you know now

You can describe how Prometheus pulls from the four endpoints, how a `ServiceMonitor` selects them, and how `up` proves a scrape works. The next question is what the labels on each series let you ask.
