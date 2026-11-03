# Exporting Metrics with OpenTelemetry

The ConfigMap decides what Kyverno measures. A separate group of controller flags decides how the numbers leave the process. This chapter explains the two export modes and the flags that choose between them.

## OpenTelemetry inside Kyverno

OpenTelemetry (OTel) is a vendor-neutral standard and set of libraries for producing metrics and traces. Kyverno creates its instruments (counters and histograms) with the OpenTelemetry SDK. The SDK then hands the data to an exporter. Kyverno supports two exporters, and you pick one with the `--otelConfig` flag.

## Mode one: Prometheus scrape endpoint

With `--otelConfig=prometheus`, the default, each controller opens an HTTP server on the metrics port and serves the Prometheus text format at `/metrics`. Prometheus pulls from it. This is the mode used in every example so far.

The related flags are:

- `--disableMetrics`: when `true`, no metrics are produced at all.
- `--metricsPort`: the port of the HTTP server, `8000` by default.
- `--metricsConfig`: the name of the ConfigMap that holds the `namespaces`, `metricsExposure` and `bucketBoundaries` keys. The default is `kyverno-metrics`.

## Mode two: push to an OpenTelemetry Collector

With `--otelConfig=grpc`, Kyverno pushes metrics over gRPC to an OpenTelemetry Collector (a separate process that receives, processes and forwards telemetry). You also set `--otelCollector` to the collector address, for example `opentelemetrycollector.monitoring.svc:4317`. When the collector uses TLS, `--transportCreds` names the secret that holds the credentials.

The collector can then forward the data to Prometheus remote write, to a cloud monitoring service, or to several back ends. In this mode there is nothing to scrape, so a `ServiceMonitor` finds no data. This is the most common surprise when someone switches modes.

## Setting the flags

Kyverno flags are container arguments on each controller Deployment. With the Helm chart you set them through values, for example in the `extraArgs` list of a controller:

```yaml
admissionController:
  container:
    extraArgs:
      - --otelConfig=grpc
      - --otelCollector=opentelemetrycollector.monitoring.svc:4317
```

Each controller reads its own flags. If you change the mode on the admission controller only, the other three controllers keep serving Prometheus text. Set the flag on every controller that you want to change.

You can read the flags a running controller uses:

```sh
kubectl -n kyverno get deploy kyverno-admission-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}'
```

> [!TIP]
> **Try it - read the live flags**
>
> Run the command above for each of the four controller Deployments: `kyverno-admission-controller`, `kyverno-background-controller`, `kyverno-cleanup-controller` and `kyverno-reports-controller`. Note which flags are set explicitly and which are left at their defaults.

## Common pitfalls

- Setting `--otelConfig=grpc` without `--otelCollector`, so the exporter has no address to send to.
- Changing the flag on one controller and assuming that all four changed.
- Keeping a `ServiceMonitor` after switching to `grpc` mode. The target stays up if the Service exists, but no useful series arrive.
- Setting `--disableMetrics=true` for a test and forgetting it. Every dashboard then shows no data.

## What you know now

You can choose between a scrape endpoint and a collector push, and you know which flag does what. Choosing what to measure still leaves a cost question, which is how many series the choice creates.
