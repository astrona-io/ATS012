# Section 030: Kyverno Metrics

Welcome to the final domain in Policy Management. Sections 010 and 020 were about your *workloads* — what is non-compliant, and what is deliberately excused. This section is about *Kyverno itself*: how much latency the admission webhook adds to every write in your cluster, which rules are failing and how fast, whether a policy quietly disappeared overnight, and whether the controllers are keeping up with the work.

All of that lives in a Prometheus endpoint that a stock install has been serving since the moment you ran `kubectl create -f install.yaml` — and in a ConfigMap that decides, deliberately, how much of it you are allowed to see.

---

## What You Will Master

By completing this section, you will acquire two core Policy Management competencies:
*   **Reading the Metrics Endpoint:** Port 8000 and `/metrics`, the four per-controller metrics Services and which one answers which question, the `--disableMetrics`/`--otelConfig`/`--metricsPort` flags, three ways to scrape by hand, and the six metric families worth knowing by name — including why the docs say `kyverno_policy_results` while your endpoint says `kyverno_policy_results_total`.
*   **Configuring Metrics & Using Them:** The `kyverno-metrics` ConfigMap and its `namespaces`, `metricsExposure` and `bucketBoundaries` keys, why `resource_namespace` ships disabled and what it costs to turn back on, why a change needs a controller restart, the four alerts actually worth having, and how to diagnose a latency incident from metrics alone.

---

## The Learning & Lab Path

This section is divided into two sequential modules, each paired with a dedicated graded lab on a kind Kubernetes cluster. The section concludes with a comprehensive Capstone Integration Challenge:

### 1. The Metrics Endpoint & Core Metric Families
*   **Module Reader:** **[Module 1: The Metrics Endpoint & Core Metric Families](./module-01/course.md)**
    1. [The Metrics Endpoint and Its Services](./module-01/course-01-metrics-endpoint-and-services.md)
    2. [The Core Metric Families](./module-01/course-02-core-metric-families.md)
*   **Practice Lab Sandbox:** **`sections/section-030/module-01/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-01/labs/lab-01
    ```
*   **Hands-on Objective:** Scrape Kyverno's metrics endpoint from inside the cluster, then drive real traffic through an `Enforce` policy — one admitted Pod, one rejected Pod — and find both outcomes in `kyverno_policy_results_total` and the policy inventory in `kyverno_policy_rule_info_total`.

### 2. Configuring Metrics & Controlling Cardinality
*   **Module Reader:** **[Module 2: Configuring Metrics & Controlling Cardinality](./module-02/course.md)**
    1. [The kyverno-metrics ConfigMap](./module-02/course-01-the-kyverno-metrics-configmap.md)
    2. [Using Metrics in Practice](./module-02/course-02-using-metrics-in-practice.md)
*   **Practice Lab Sandbox:** **`sections/section-030/module-02/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-02/labs/lab-01
    ```
*   **Hands-on Objective:** Re-enable the `resource_namespace` dimension so failures can be attributed per namespace, exclude a noisy namespace from measurement entirely, replace the default histogram buckets with a coarser set, and prove all three on the raw endpoint.

### 3. Section Capstone Challenge
*   **Comprehensive Challenge:** **`sections/section-030/capstone/labs/lab-01` (Kyverno Metrics Integration)**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/capstone/labs/lab-01
    ```
*   **Hands-on Objective:** Configure metrics for a two-namespace estate — one measured with full attribution, one excluded — drive both admitted and rejected traffic through an `Enforce` policy, and prove from the endpoint alone which namespace produced the failures and that the excluded one produced no series at all.

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the practical lab missions:

*   **[Take the Section 030 Knowledge Check Quiz](./quiz.md)**
