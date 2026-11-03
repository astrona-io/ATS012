# Summary

The `kyverno-metrics` ConfigMap decides what is measured. Every label you enable multiplies the number of time series.

## What you learned

The ConfigMap has three keys. `namespaces` (`include` and `exclude`) restricts which namespaces are measured; an empty `include` means all. Excluding a namespace stops counting there but never changes enforcement or reporting. `metricsExposure` lists, per metric, which label dimensions are disabled; `resource_namespace` ships disabled on `kyverno_policy_results_total`, and emptying `disabledLabelDimensions` turns it on at the price of more series. `bucketBoundaries` sets the histogram `le` values. The configuration is read when the instruments are built, so restart the admission controller before you expect a change.

In practice the alerts worth having are few: rejected requests rising, admission latency high, controllers erroring. A slow cluster after a policy rollout is diagnosed from the admission latency quantile first, and a low value points away from Kyverno. Metrics tell you how many and how long; reports tell you which resource.

The export mode is chosen with `--otelConfig`: `prometheus` serves a scrape endpoint and `grpc` pushes to an OpenTelemetry Collector set with `--otelCollector`. Each controller reads its own flags. Cardinality is the number of distinct series, and it grows by multiplication across labels and histogram buckets. Count series with PromQL, and reduce them by excluding namespaces, keeping labels disabled, using fewer buckets or switching a metric off.

The key facts to remember are these:

- Three keys: `namespaces`, `metricsExposure`, `bucketBoundaries`.
- Metrics configuration is separate from enforcement.
- Restart to apply a metrics configuration change.
- Use metrics for rates and latency, reports for named resources.

<!-- astrona:playground:destroy -->
