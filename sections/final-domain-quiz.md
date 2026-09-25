# KCA Policy Management Certification Quiz

Welcome to the Final Domain Certification Quiz for the **ATS012: Policy Management** curriculum. This comprehensive test contains **18 high-signal, scenario-based questions** covering all 6 modules across the 3 sections.

To simulate exam-style pressure:
*   Answer all 18 questions without consulting external documentation, the Kyverno CLI, or a cluster.
*   Allow yourself a maximum of **30 minutes** to complete the entire test.
*   Once finished, scroll to the very bottom to check the **Audit and Review Key** to trace any incorrect answers back to their exact section and module chapters.

---

## The Exam Simulator

### Question 1
A `ClusterPolicy` reports a violation on a `PersistentVolume`. Which report object holds it?
*   **A)** A `PolicyReport` in the `kyverno` namespace.
*   **B)** A `ClusterPolicyReport`, because `PersistentVolume` is cluster-scoped.
*   **C)** A `PolicyReport` in the namespace of the Pod using the volume.
*   **D)** Neither; cluster-scoped resources are not reported on.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The report kind follows the scope of the *reported resource*, never the policy. A cluster-scoped resource's findings go into `ClusterPolicyReport` (`cpolr`).
*   **Why others are incorrect:** *A* invents a central collection namespace. *C* invents a relationship to consumers of the resource. *D* is contradicted by the existence of `ClusterPolicyReport`.
</details>

---

### Question 2
Why is a modern Kyverno `PolicyReport` named after a UUID?
*   **A)** To avoid name collisions between policies.
*   **B)** Because it is the reported resource's `metadata.uid` — reports are stored per-resource, with an owner reference so they are garbage-collected with the resource.
*   **C)** Because report names are randomly regenerated on each scan.
*   **D)** Because the UUID encodes the policy and rule names.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Since Kyverno 1.10 the model is one report per resource, named by that resource's UID, owned by it. You locate one via the `KIND`/`NAME` printer columns or from the resource's UID — never by guessing.
*   **Why others are incorrect:** *A* misidentifies what is being disambiguated. *C* would break owner references and garbage collection. *D* invents an encoding.
</details>

---

### Question 3
A report result shows `result: warn`. What produced it?
*   **A)** A rule whose severity is set to `medium`.
*   **B)** A precondition that evaluated false.
*   **C)** A failure on a policy annotated `policies.kyverno.io/scored: "false"`, which downgrades failures to warnings.
*   **D)** A variable substitution error.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** `warn` exists only because a policy was marked advisory with `scored: "false"`. Its violations increment `summary.warn` and leave `summary.fail` at zero — which is why a CI gate written only against `fail` silently ignores such policies.
*   **Why others are incorrect:** *A* confuses the independent `severity` field with the result value. *B* produces `skip`. *D* produces `error`.
</details>

---

### Question 4
You apply a policy to a cluster full of long-running workloads. New violations appear in reports within seconds; the pre-existing ones do not appear at all after ten minutes. What is the most likely explanation?
*   **A)** Pre-existing resources are never reported on.
*   **B)** The admission path is immediate; pre-existing resources wait for the reports controller's background scan, whose `--backgroundScanInterval` defaults to `1h`.
*   **C)** The background controller has crashed.
*   **D)** `validationFailureAction: Audit` suppresses reports for old resources.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Two producers, two clocks. Admission-time findings are recorded as part of handling the request; pre-existing resources generate no request and wait for a periodic scan, hourly by default.
*   **Why others are incorrect:** *A* contradicts the purpose of background scanning. *C* names the wrong controller — report scanning belongs to `kyverno-reports-controller`. *D* inverts what `Audit` does.
</details>

---

### Question 5
You add `[*/*,noisy-ns,*]` to `resourceFilters` in the `kyverno` ConfigMap, yet `noisy-ns` still produces `PolicyReport` entries. What is happening?
*   **A)** `resourceFilters` only accepts `[kind,name]` pairs.
*   **B)** The reports controller defaults to `--skipResourceFilters=true`, so background scans deliberately ignore `resourceFilters`. Set it to `false`.
*   **C)** The ConfigMap requires a controller restart before any entry applies.
*   **D)** `resourceFilters` applies only to `generate` rules.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The flag means "skip *applying* the filters", and `true` is the shipped default on the reports controller — the design intent being that a performance exclusion at the webhook should not silently blind compliance reporting.
*   **Why others are incorrect:** *A* misstates the `[kind,namespace,name]` format. *C* is wrong — the ConfigMap is watched. *D* invents a rule-type restriction.
</details>

---

### Question 6
Your reports are permanently an hour stale and a single background scan cycle is taking longer than the interval between cycles. What is the right first move?
*   **A)** Lower `--backgroundScanInterval` so scans start more frequently.
*   **B)** Raise `--backgroundScanWorkers` so each cycle finishes faster.
*   **C)** Set `--policyReports=false`.
*   **D)** Delete the existing report objects.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The symptom is a cycle that cannot complete in its own window. Worker count is the lever that makes a cycle faster; only once cycles complete comfortably is the interval worth revisiting.
*   **Why others are incorrect:** *A* makes a backlog worse by starting more cycles. *C* disables the system instead of fixing it. *D* treats a symptom — reports are owned by resources and regenerate.
</details>

---

### Question 7
You create a `PolicyException` and the policy keeps blocking. What do you check first?
*   **A)** The `match` block's `names` wildcard.
*   **B)** Whether the referenced policy still exists.
*   **C)** Whether `--enablePolicyException=true` and a matching `--exceptionNamespace` are set on the controllers — the feature is off by default and fails completely silently.
*   **D)** Whether the exception has an `expires` annotation in the past.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** The CRD ships installed but the feature ships disabled. Without the flag the object is stored happily and has no effect — no error, no event, no warning anywhere.
*   **Why others are incorrect:** *A* and *B* are real causes but much less common, and cheap to check second. *D* invents built-in expiry handling; Kyverno does not interpret an `expires` annotation.
</details>

---

### Question 8
A Deployment is blocked by a policy whose only rule is `check-limits`, matching `kinds: [Pod]`. Which `ruleNames` does a working exception need?
*   **A)** `check-limits` only.
*   **B)** `check-limits` and `autogen-check-limits`.
*   **C)** `autogen-check-limits` only, since Deployments are never matched directly.
*   **D)** None; `ruleNames` is optional and defaults to all rules.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Autogen adds `autogen-`-prefixed copies of a Pod-scoped rule for Pod-owning controllers. The Deployment request is rejected by `autogen-check-limits`; the Pods the ReplicaSet then creates are judged by `check-limits`. Covering the whole workload needs both, and the exception's `match` must include the `Deployment` kind as well as `Pod`.
*   **Why others are incorrect:** *A* leaves the blocking rule un-waived. *C* leaves the Pods blocked. *D* invents a default.
</details>

---

### Question 9
An exception's `match` uses `names: ["batch-runner"]`. The Deployment is admitted; its Pods are still blocked. Why?
*   **A)** Pods require a separate exception object.
*   **B)** Exceptions cannot cover resources created by controllers.
*   **C)** The Pods are named `batch-runner-<hash>-<hash>`, so an exact-name match misses them; use `batch-runner*`.
*   **D)** The exception's `background` field is `false`.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** ReplicaSets append hashes to Pod names. A prefix wildcard covers the controller and the Pods it spawns; an exact name covers only the controller.
*   **Why others are incorrect:** *A* and *B* invent restrictions — one exception can match several kinds and names. *D* would affect background scanning, not admission.
</details>

---

### Question 10
Exceptions are enabled on the admission controller only. What is the observable result?
*   **A)** Nothing works; exceptions need all four controllers.
*   **B)** The exempted workload is admitted, but reports still record `fail` instead of `skip`, because the reports controller does not honour the exception.
*   **C)** The workload stays blocked, but reports show `skip`.
*   **D)** Exceptions apply, but only to cluster-scoped resources.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Each controller applies the flag to its own work: admission decides whether the resource is admitted, reports decides whether a scan records `skip`. Half-enabling produces exactly this enforcement-versus-record mismatch — and the report is what an auditor reads.
*   **Why others are incorrect:** *A* overstates it — the cleanup controller is irrelevant here. *C* is the reverse case (reports only). *D* invents a scope restriction.
</details>

---

### Question 11
What does adding a `conditions` block to a `PolicyException` buy you over simply narrowing `match`?
*   **A)** It makes the exception apply during background scans.
*   **B)** It removes the need to list `autogen-` rule names.
*   **C)** A second, independent gate evaluated against live request data — so each workload must opt in itself, for example by carrying a specific label, and that claim is visible in the workload's own manifest.
*   **D)** It lets one exception cover several policies.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** `match` selects candidates by identity; `conditions` applies `any`/`all` key/operator/value tests with JMESPath substitution against the request. The review benefit is real: the exemption claim lives in the exempted thing.
*   **Why others are incorrect:** *A* is `spec.background`'s job. *B* is unrelated — autogen names are still needed. *D* is done with multiple `spec.exceptions[]` entries.
</details>

---

### Question 12
A policy should permanently never apply to `kube-system`, and separately one legacy workload needs a temporary waiver. What is the right pairing?
*   **A)** `exclude` for both.
*   **B)** `PolicyException` for both.
*   **C)** `exclude` for `kube-system` (that is the policy's real scope), `PolicyException` for the legacy workload (a tolerated, owned, time-bound deviation).
*   **D)** `resourceFilters` for both.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** Scope belongs in the policy; deviations belong in a named, reviewable object that shows up in reports as `skip`. Excluded resources produce no report results at all, which is right for out-of-scope things and wrong for things you are tolerating.
*   **Why others are incorrect:** *A* hides a temporary waiver inside the enforcement document with no audit trail. *B* turns permanent scope into a perpetual "temporary" exemption. *D* is a cluster-wide evaluation filter, far too blunt for either job.
</details>

---

### Question 13
Which Service and port do you scrape for Kyverno's admission controller metrics?
*   **A)** `kyverno-svc` on 443.
*   **B)** `kyverno-admission-controller-metrics` on 8000.
*   **C)** `kyverno-svc-metrics` on 8000, path `/metrics`.
*   **D)** `kyverno-reports-controller-metrics` on 8000.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** All four controllers serve metrics on 8000 at `/metrics`, and the admission controller's metrics Service is named after its main Service (`kyverno-svc`), not after its Deployment.
*   **Why others are incorrect:** *A* is the TLS webhook endpoint. *B* is the name people guess; it does not exist. *D* is real, but serves the reports controller's own metrics.
</details>

---

### Question 14
`kyverno_policy_rule_info_total` wrapped in `rate()` returns near-zero. Why?
*   **A)** The metric is disabled by default.
*   **B)** It is a gauge reporting `1` per active rule — an inventory, not an event counter — despite the `_total` suffix.
*   **C)** It only updates after a background scan.
*   **D)** `rate()` cannot be used on metrics with more than five labels.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Rate of change over a constant `1` is zero. Count the series instead: `count(count(kyverno_policy_rule_info_total{...} == 1) by (policy_name))`. This is also the metric that catches a policy being deleted, which every other family reports as silence.
*   **Why others are incorrect:** *A*, *C* and *D* all invent behaviour; the suffix is the only misleading thing here, and it comes from the Prometheus exporter's counter convention.
</details>

---

### Question 15
Which label on `kyverno_policy_results_total` distinguishes a deploy-time rejection from an hourly background re-scan of the same old violation?
*   **A)** `policy_background_mode`
*   **B)** `resource_request_operation`
*   **C)** `policy_validation_mode`
*   **D)** `rule_execution_cause`, with values `admission_request` and `background_scan`

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: D**

*   **Why D is correct:** Without filtering on it, a scan cycle re-confirming known violations looks identical to a rollout blocking real traffic — two very different pages at 3am.
*   **Why others are incorrect:** *A* describes the policy's configuration, not this evaluation's trigger. *B* is `create`/`update`/`delete`. *C* is `enforce`/`audit`.
</details>

---

### Question 16
You cannot find a `resource_namespace` label on `kyverno_policy_results_total`. What is going on and what is the cost of changing it?
*   **A)** The endpoint is broken; restart the controller.
*   **B)** It ships in `disabledLabelDimensions` in the `kyverno-metrics` ConfigMap; enabling it multiplies the series count by the number of namespaces.
*   **C)** It only appears on histogram metrics.
*   **D)** It requires the Prometheus Operator to be installed.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Kyverno deliberately disables the highest-cardinality dimensions on the busiest metrics. Re-enable per metric, where you will actually read it — every label value combination is a stored time series.
*   **Why others are incorrect:** *A* mistakes a default for a fault. *C* and *D* invent mechanisms.
</details>

---

### Question 17
You edit `bucketBoundaries` and `metricsExposure` in `kyverno-metrics`, then scrape and see no change. What is missing, and what does fixing it cost?
*   **A)** Nothing is missing; the change propagates within an hour.
*   **B)** `--disableMetrics` must be set to `false` first.
*   **C)** The affected controllers need a `rollout restart` — instruments are built at process start — and the restart resets process-lifetime counters to zero.
*   **D)** The ConfigMap must be renamed to `kyverno`.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** Label sets and bucket boundaries are fixed when the instruments are created. A restart applies them; the side effect is counters starting from zero, which `rate()` and `increase()` handle but an absolute-value dashboard does not.
*   **Why others are incorrect:** *A* invents a refresh interval. *B* is already the default. *D* names the ConfigMap that holds `resourceFilters`, a different system entirely.
</details>

---

### Question 18
You need to know exactly which Pods currently violate a policy, and separately whether violations are trending upwards. Which signals?
*   **A)** Metrics for both — filter by `resource_name`.
*   **B)** Reports for both; metrics carry no timing information.
*   **C)** Reports for "which Pods" (they carry `scope` per resource); metrics for "is it getting worse" (aggregates over time, no resource identity).
*   **D)** Admission controller logs for both.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: C**

*   **Why C is correct:** These are complementary by design. Reports are an inventory naming each resource; metrics are aggregates with no per-resource label (adding one would create a series per resource). Using either alone is how investigations go sideways.
*   **Why others are incorrect:** *A* invents a `resource_name` label that does not and should not exist. *B* ignores that metrics are precisely the time-series signal. *D* makes logs the primary interface, which they are not.
</details>

---

## Audit and Review Key

| Question | Correct Answer | Review Section |
| :--- | :--- | :--- |
| 1 | B | [Section 010, Module 1.1](./section-010/module-01/course-01-policyreport-and-clusterpolicyreport.md) |
| 2 | B | [Section 010, Module 1.1](./section-010/module-01/course-01-policyreport-and-clusterpolicyreport.md) |
| 3 | C | [Section 010, Module 1.2](./section-010/module-01/course-02-reading-results-and-result-types.md) |
| 4 | B | [Section 010, Module 2.1](./section-010/module-02/course-01-the-reports-pipeline.md) |
| 5 | B | [Section 010, Module 2.2](./section-010/module-02/course-02-tuning-and-troubleshooting-reports.md) |
| 6 | B | [Section 010, Module 2.2](./section-010/module-02/course-02-tuning-and-troubleshooting-reports.md) |
| 7 | C | [Section 020, Module 1.1](./section-020/module-01/course-01-enabling-policyexceptions.md) |
| 8 | B | [Section 020, Module 1.2](./section-020/module-01/course-02-anatomy-of-a-policyexception.md) |
| 9 | C | [Section 020, Module 1.2](./section-020/module-01/course-02-anatomy-of-a-policyexception.md) |
| 10 | B | [Section 020, Module 1.1](./section-020/module-01/course-01-enabling-policyexceptions.md) |
| 11 | C | [Section 020, Module 2.1](./section-020/module-02/course-01-conditions-podsecurity-and-background.md) |
| 12 | C | [Section 020, Module 2.2](./section-020/module-02/course-02-governance-and-alternatives.md) |
| 13 | C | [Section 030, Module 1.1](./section-030/module-01/course-01-metrics-endpoint-and-services.md) |
| 14 | B | [Section 030, Module 1.2](./section-030/module-01/course-02-core-metric-families.md) |
| 15 | D | [Section 030, Module 1.2](./section-030/module-01/course-02-core-metric-families.md) |
| 16 | B | [Section 030, Module 2.1](./section-030/module-02/course-01-the-kyverno-metrics-configmap.md) |
| 17 | C | [Section 030, Module 2.1](./section-030/module-02/course-01-the-kyverno-metrics-configmap.md) |
| 18 | C | [Section 030, Module 2.2](./section-030/module-02/course-02-using-metrics-in-practice.md) |
