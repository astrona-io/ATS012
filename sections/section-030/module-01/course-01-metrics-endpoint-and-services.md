# Part 1 — The Metrics Endpoint and Its Services

> Prerequisite: [Module landing page](./course.md). Next: [Part 2 — The Core Metric Families](./course-02-core-metric-families.md).

## One endpoint per controller, all on 8000

Every Kyverno controller exposes Prometheus-format metrics on **port 8000**, path **`/metrics`**, and a stock `install.yaml` creates one Service per controller to front them:

```sh
kubectl get svc -n kyverno
```
```text
NAME                                     TYPE        CLUSTER-IP      PORT(S)
kyverno-svc                              ClusterIP   10.96.121.44    443/TCP
kyverno-svc-metrics                      ClusterIP   10.96.14.201    8000/TCP
kyverno-background-controller-metrics    ClusterIP   10.96.180.9     8000/TCP
kyverno-cleanup-controller               ClusterIP   10.96.77.132    443/TCP
kyverno-cleanup-controller-metrics       ClusterIP   10.96.55.3      8000/TCP
kyverno-reports-controller-metrics       ClusterIP   10.96.4.88      8000/TCP
```

Note the naming asymmetry: the admission controller's metrics Service is `kyverno-svc-metrics` (matching its main Service `kyverno-svc`), while the other three are named after their controller. It is a small thing that costs people ten minutes when they go looking for `kyverno-admission-controller-metrics` and find nothing.

Each endpoint only carries what its own controller measures, which is the practical reason to know which is which:

| Question | Scrape |
| :--- | :--- |
| How much latency does admission control add? | `kyverno-svc-metrics` |
| How many policies/rules exist and in what mode? | `kyverno-svc-metrics` |
| Are background scans keeping up? | `kyverno-reports-controller-metrics` |
| Are `generate` rules reconciling? | `kyverno-background-controller-metrics` |
| Is `CleanupPolicy` deleting what it should? | `kyverno-cleanup-controller-metrics` |

The `kyverno_controller_reconcile_total`, `kyverno_controller_requeue_total` and `kyverno_controller_drop_total` families appear on several endpoints, each reporting that controller's own work queues. A drop counter climbing anywhere is worth an alert: it means work was thrown away, not retried.

## The flags that govern exposure

```sh
kubectl get deployment kyverno-admission-controller -n kyverno \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -iE 'metric|otel'
```
```text
"--disableMetrics=false"
"--otelConfig=prometheus"
"--metricsPort=8000"
```

- **`--disableMetrics`** (default `false`) — set `true` and the endpoint stops serving entirely. Reach for it only on a cluster with no monitoring at all, where the instrumentation cost buys you nothing.
- **`--otelConfig`** (default `prometheus`) — `prometheus` serves a scrape endpoint; `grpc` pushes to an OpenTelemetry collector instead (paired with `--otelCollector`). Kyverno's instrumentation is OpenTelemetry underneath, and the Prometheus endpoint is one exporter for it. That detail matters in Part 2.
- **`--metricsPort`** (default `8000`) — the port. Change it and you must change the Service's `targetPort` too.

A stock install also ships `ServiceMonitor` objects for each controller, so a Prometheus Operator installation picks Kyverno up with no extra configuration once the CRD exists.

## Three ways to read the endpoint by hand

**1. Port-forward to your own machine** — the fastest for interactive poking:

```sh
kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8000:8000 &
curl -s http://localhost:8000/metrics | head -30
```

**2. `kubectl exec` from a Pod already in the cluster** — the reliable one for scripts and validation, since it needs no local port and no background process:

```sh
kubectl exec metrics-probe -- \
  curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics | grep '^kyverno_policy_results'
```

**3. A throwaway Pod** — when you have no probe Pod handy:

```sh
kubectl run metrics-probe --rm -i --restart=Never --image=curlimages/curl:8.5.0 -- \
  -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics | grep '^kyverno_admission_requests'
```

The output is ordinary Prometheus text format: a `# HELP` line, a `# TYPE` line, then one line per label combination.

```text
# HELP kyverno_policy_results_total can be used to track the results associated with the policies applied in the user's cluster
# TYPE kyverno_policy_results_total counter
kyverno_policy_results_total{policy_background_mode="true",policy_name="require-limits",policy_type="cluster",policy_validation_mode="enforce",resource_kind="Pod",resource_request_operation="create",rule_execution_cause="admission_request",rule_name="check-limits",rule_result="fail",rule_type="validate"} 3
```

> [!TIP]
> **Try it — confirm the endpoint is alive and find one metric**
>
> ```sh
> kubectl get svc kyverno-svc-metrics -n kyverno
> kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics | wc -l
> kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics | grep -c '^kyverno_'
> ```
>
> A healthy endpoint returns hundreds of lines, a few hundred of which start with `kyverno_`. If you get zero, check `--disableMetrics` before you check anything else.

> [!WARNING]
> **Common pitfall**
>
> Scraping `kyverno-svc` (port 443) instead of `kyverno-svc-metrics` (port 8000). `kyverno-svc` is the webhook endpoint — it speaks TLS and expects `AdmissionReview` payloads, so a plain `curl` there gives you a confusing TLS error rather than "wrong port".

## Reference

- `kubectl get svc -n kyverno` — the metrics Services and their ports.
- `kubectl get servicemonitor -n kyverno` — present when the Prometheus Operator CRDs are installed.
- [Kyverno docs — Monitoring](https://kyverno.io/docs/monitoring/) — upstream reference, including Grafana dashboard examples.
