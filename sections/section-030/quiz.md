# Section 030 Knowledge Check: Kyverno Metrics

Test your understanding of the metrics endpoint and its Services, the core metric families and their labels, the `kyverno-metrics` ConfigMap, cardinality control, and diagnosing real problems from the numbers.

---

## Scenario-Based Questions

### Question 1
You want to scrape Kyverno's admission controller metrics from inside the cluster. Which Service and port?
*   **A)** `kyverno-svc` on port 443.
*   **B)** `kyverno-svc-metrics` on port 8000, path `/metrics`.
*   **C)** `kyverno-admission-controller-metrics` on port 9090.
*   **D)** `kyverno-reports-controller-metrics` on port 8000.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Every Kyverno controller serves Prometheus metrics on port 8000 at `/metrics`, and the admission controller's metrics Service is named `kyverno-svc-metrics` — matching its main Service `kyverno-svc` rather than its Deployment name.
*   **Why others are incorrect:**
    *   *Option A* is the webhook endpoint: TLS on 443, expecting `AdmissionReview` payloads. A plain `curl` there fails confusingly.
    *   *Option C* invents a Service name that does not exist (the naming trap) and the wrong port.
    *   *Option D* is a real Service, but it serves the reports controller's own metrics — no admission latency there.
</details>

---

### Question 2
The Kyverno docs refer to `kyverno_policy_results`. Your `/metrics` endpoint shows `kyverno_policy_results_total`. What is going on?
*   **A)** Two different metrics with overlapping purposes.
*   **B)** Kyverno instruments with OpenTelemetry; its Prometheus exporter appends the conventional `_total` suffix to counters at export time. Query the name the endpoint shows.
*   **C)** The `_total` version is deprecated.
*   **D)** `_total` only appears once the counter exceeds zero.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The instrument name in code and documentation has no suffix; the Prometheus exporter adds `_total` because that is the Prometheus convention for counters. PromQL must use the exported name. Grepping the prefix (`^kyverno_policy_results`) matches either form.
*   **Why others are incorrect:**
    *   *Option A* invents a second metric.
    *   *Option C* invents a deprecation.
    *   *Option D* invents conditional naming; the `# TYPE` line is present regardless of value.
</details>

---

### Question 3
Which label on `kyverno_policy_results_total` separates live admission traffic from background-scan re-evaluation?
*   **A)** `policy_background_mode`
*   **B)** `rule_execution_cause`, with values `admission_request` and `background_scan`
*   **C)** `policy_validation_mode`
*   **D)** `resource_request_operation`

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `rule_execution_cause` records what triggered the evaluation. Without filtering on it, a spike caused by hourly background scans looks identical to a spike caused by real deploy traffic being rejected — two very different incidents.
*   **Why others are incorrect:**
    *   *Option A* reports whether the policy has background mode enabled, not what caused this particular evaluation.
    *   *Option C* is `enforce` versus `audit`.
    *   *Option D* is `create`/`update`/`delete`.
</details>

---

### Question 4
You wrap `kyverno_policy_rule_info_total` in `rate()` and get meaningless near-zero numbers. Why?
*   **A)** The metric is disabled by default.
*   **B)** It is a gauge reporting `1` per active rule — an inventory, not an event count — despite the `_total` suffix. Count it with `count(... == 1)` instead.
*   **C)** `rate()` requires a five-minute window and you used a shorter one.
*   **D)** The metric only populates after a background scan.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `kyverno_policy_rule_info_total` is a gauge whose value is `1` for each rule currently present in the cluster. Rate-of-change over a constant is zero. The useful query counts distinct series, e.g. `count(count(kyverno_policy_rule_info_total{policy_validation_mode="enforce"} == 1) by (policy_name))`.
*   **Why others are incorrect:**
    *   *Option A* is wrong — it ships enabled, with `resource_namespace`/`policy_namespace` dimensions disabled.
    *   *Option C* misattributes the problem to the window.
    *   *Option D* is wrong — it reflects policy inventory, available as soon as a policy exists.
</details>

---

### Question 5
You scrape a stock Kyverno install and cannot find a `resource_namespace` label on `kyverno_policy_results_total`. Is something broken?
*   **A)** Yes — the metrics endpoint is misconfigured.
*   **B)** No. The default `metricsExposure` in the `kyverno-metrics` ConfigMap lists `resource_namespace` (and `policy_namespace`) under `disabledLabelDimensions` for that metric, to keep series cardinality down.
*   **C)** No — that label only appears on histogram metrics.
*   **D)** Yes — the reports controller must be restarted to publish it.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Kyverno deliberately ships with the highest-cardinality label dimensions disabled on the busiest metrics. Adding `resource_namespace` multiplies the series count by the number of namespaces, which on a large cluster is a real cost. You can re-enable it per metric when you need the attribution.
*   **Why others are incorrect:**
    *   *Option A* mistakes a deliberate default for a fault.
    *   *Option C* invents a restriction.
    *   *Option D* has the mechanism backwards — a restart applies a config change, it does not add labels that configuration disabled.
</details>

---

### Question 6
Which key in the `kyverno-metrics` ConfigMap restricts *which namespaces are measured at all*, and what happens when `include` is empty?
*   **A)** `metricsExposure`; an empty `include` disables the metric.
*   **B)** `namespaces`, holding JSON with `include` and `exclude` lists; an empty `include` means all namespaces are measured, and `exclude` takes precedence.
*   **C)** `bucketBoundaries`; an empty `include` means default buckets.
*   **D)** `resourceFilters`; an empty `include` means nothing is measured.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `namespaces` is a JSON string like `{"exclude":[],"include":[]}`. Empty `include` means everything is measured; populating it narrows measurement to those namespaces; `exclude` is applied on top and wins.
*   **Why others are incorrect:**
    *   *Option A* is per-metric label and on/off control, not namespace selection.
    *   *Option C* is histogram bucket boundaries.
    *   *Option D* is a key in the *`kyverno`* ConfigMap and controls policy *evaluation*, not measurement.
</details>

---

### Question 7
You exclude `ci-builds` from the `namespaces` key of `kyverno-metrics`. What happens to policy enforcement in `ci-builds`?
*   **A)** Policies stop applying there.
*   **B)** Nothing — enforcement is unchanged. You have stopped counting, not stopped policing; `resourceFilters` in the `kyverno` ConfigMap is what controls evaluation.
*   **C)** Policies apply but stop producing PolicyReports there.
*   **D)** Only `Audit`-mode policies stop applying there.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Metrics configuration and policy evaluation are separate systems. A namespace excluded from metrics is still fully evaluated, still blocked or admitted the same way, and still reported on.
*   **Why others are incorrect:**
    *   *Option A* and *Option D* confuse measurement with enforcement.
    *   *Option C* confuses metrics configuration with reporting configuration, which lives in the reports controller's flags and `resourceFilters`.
</details>

---

### Question 8
You edit `metricsExposure` and `bucketBoundaries`, then scrape immediately and see no change. What did you forget?
*   **A)** Metrics take one hour to refresh.
*   **B)** Instruments are built at controller startup, so the affected controllers need a `rollout restart` — accepting that this resets counters to zero.
*   **C)** You must also set `--disableMetrics=false`.
*   **D)** The ConfigMap must be named `kyverno` rather than `kyverno-metrics`.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Label sets and histogram bucket boundaries are fixed when the instruments are created at process start. Restarting the relevant controllers applies the new configuration; the side effect is that process-lifetime counters restart at zero, which `rate()` and `increase()` handle correctly.
*   **Why others are incorrect:**
    *   *Option A* invents a refresh interval.
    *   *Option C* is already the default, and would be an all-or-nothing switch anyway.
    *   *Option D* is wrong — `kyverno-metrics` is the correct ConfigMap; `kyverno` holds `resourceFilters` and webhook configuration.
</details>

---

### Question 9
A team says deploys got slow after a policy rollout. Admission `histogram_quantile(0.99, ...)` over `kyverno_admission_review_duration_seconds_bucket` sits at 12ms. What is the correct conclusion, and what would you check next if it had been 2 seconds?
*   **A)** Kyverno is the cause; check `kyverno_policy_changes_total`.
*   **B)** 12ms of added admission latency does not explain slow deploys, so look elsewhere. Had it been 2s, the next step is `kyverno_policy_execution_duration_seconds` to find which rule is expensive, then `kyverno_client_queries_total` to see whether it is making API calls per evaluation.
*   **C)** The quantile is meaningless without the `_sum` series.
*   **D)** Kyverno is the cause; the histogram under-reports because buckets stop at 30s.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The p99 of end-to-end admission review is exactly the latency Kyverno adds to matching writes. At 12ms it is not the explanation, and you have evidence rather than opinion. The escalation path for a genuinely high value is per-rule timing first, then Kyverno's own API call rate.
*   **Why others are incorrect:**
    *   *Option A* asserts causation the data contradicts; `kyverno_policy_changes_total` tells you *when* policy changed, not that it is slow.
    *   *Option C* is wrong — `histogram_quantile` needs the `_bucket` series, which is what was used.
    *   *Option D* invents an under-reporting argument; anything above the top boundary lands in `+Inf`, and 12ms is nowhere near it.
</details>

---

### Question 10
You need to know which specific Pods violate a policy. Metrics or reports?
*   **A)** Metrics — filter `kyverno_policy_results_total` by `resource_name`.
*   **B)** Reports. Metrics are aggregates and carry no resource identity; `PolicyReport` objects name every non-compliant resource via their `scope`.
*   **C)** Either; both carry per-resource identity.
*   **D)** Neither; you must read the admission controller's logs.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** There is no `resource_name` label on Kyverno's metrics, and there could not sensibly be one — it would create a time series per resource. Metrics answer "how often, and is it getting worse"; reports answer "which resources, right now".
*   **Why others are incorrect:**
    *   *Option A* invents a label that does not exist.
    *   *Option C* misses the fundamental split between aggregates and inventory.
    *   *Option D* ignores the reporting system entirely; logs are a last resort, not the designed answer.
</details>
