# Troubleshooting a Missing Metrics Pipeline

A dashboard with no data can have causes at four levels: Kyverno, the Service, Prometheus and the query. This chapter gives an ordered way to find the broken level.

## Work from the source outward

Test each level in turn, starting at Kyverno. Stop at the first level that fails.

1. Does the controller produce metrics? Fetch the endpoint from a Pod inside the cluster:

   ```sh
   kubectl exec -n default metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno:8000/metrics | head
   ```

   If this fails, check `--disableMetrics` and `--metricsPort` on the controller, and check that the Pod is running.

2. Does the Service reach the Pod? Check that the Service has endpoints:

   ```sh
   kubectl -n kyverno get endpoints
   ```

   An empty endpoints list means the Service selector or the Pod readiness is wrong.

3. Can Prometheus reach the Service? A NetworkPolicy in the `kyverno` namespace can block traffic from the monitoring namespace. Check with `kubectl -n kyverno get networkpolicy`.

4. Does Prometheus know the target? Query `up{namespace="kyverno"}`. No series means discovery failed, usually a label selector mismatch. A value of `0` means the scrape failed.

5. Does the query return data? Run the bare metric name first, then add label filters one at a time.

## Detecting a metric that vanished

An alert on a high error count never fires if the metric does not exist. The function `absent()` returns a value when a selector matches nothing:

```promql
absent(kyverno_admission_requests_total)
absent(up{namespace="kyverno", job=~".*admission.*"})
```

Use an alert on `absent()` with a short `for:` to catch a broken pipeline. Be aware that it cannot say which of the four levels failed. The steps above do that.

## Reading wrong numbers

Wrong values are harder than missing values. Common causes:

- A label is disabled in the metrics ConfigMap, so a filter on it matches nothing.
- The query uses a counter without `rate()` or `increase()`, so a restart looks like a drop.
- The configuration change was not applied, because the admission controller was not restarted.
- The query adds up all replicas twice by mixing `sum` with a label that identifies the instance.

Compare a value from the raw endpoint with the same value in Prometheus. If they differ, the problem is in the scrape or the query. If they match, the problem is in what Kyverno measures.

> [!TIP]
> **Try it - break and find**
>
> In the playground, check each step above against the stock installation. Step 3 should show no blocking NetworkPolicy, and the commands in steps 1 and 2 should work. Then name which step would fail if the `--metricsPort` flag was changed to 9000 without changing the Service.

## Common pitfalls

- Starting at the dashboard and guessing, instead of starting at the endpoint.
- Changing the Service port but not the `ServiceMonitor` port name.
- Assuming an empty graph means zero events. It can mean no data.
- Alerting on a metric without an `absent()` guard, so a broken pipeline looks healthy.

## What you know now

You can walk the pipeline from the Kyverno endpoint to the query and find the level that fails, and you can alert on missing data.
