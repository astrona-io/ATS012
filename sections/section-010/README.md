# Section 010: Policy Reports

Welcome to the first domain in Policy Management. Enforcement is the loud half of Kyverno — a `kubectl apply` fails and somebody notices immediately. Reporting is the quiet half, and it is where most of the operational value lives: every `Audit`-mode policy and every background scan is writing its findings into objects in your cluster right now, and those objects are the only record you have of what is non-compliant but still running.

This section teaches you to read that record, and then to understand and tune the machinery that produces it — because a report you cannot explain the freshness of is a report you cannot make decisions from.

---

## What You Will Master

By completing this section, you will acquire two core Policy Management competencies:
*   **Reading Reports:** The `PolicyReport` and `ClusterPolicyReport` CRDs, why reports are named after resource UIDs, the `scope`/`results[]`/`summary` structure, what each of the five result values (`pass`, `fail`, `warn`, `error`, `skip`) actually means, and how to query for exactly the findings you care about with `kubectl` and jsonpath.
*   **Operating the Reports Pipeline:** Which controller produces admission-path findings versus background-scan findings, what the intermediate `EphemeralReport` objects are for, how `--backgroundScanInterval`, `--backgroundScanWorkers` and `--enableReporting` change behaviour and cost, why `resourceFilters` does not stop background reporting by default, and a defensible order for diagnosing a missing report.

---

## The Learning & Lab Path

This section is divided into two sequential modules, each paired with a dedicated graded lab on a kind Kubernetes cluster. The section concludes with a comprehensive Capstone Integration Challenge:

### 1. Reading PolicyReports
*   **Module Reader:** **[Module 1: Reading PolicyReports](./module-01/course.md)**
    1. [PolicyReport and ClusterPolicyReport](./module-01/course-01-policyreport-and-clusterpolicyreport.md)
    2. [Reading Results: the Five Result Types](./module-01/course-02-reading-results-and-result-types.md)
*   **Practice Lab Sandbox:** **`sections/section-010/module-01/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-01/labs/lab-01
    ```
*   **Hands-on Objective:** Apply an `Audit` policy over a namespace holding one compliant and one non-compliant workload, then prove you can find the right report, read its summary, and separate `fail` results from `pass` results — including one advisory policy whose failures arrive as `warn`.

### 2. The Reports Pipeline & Its Tuning
*   **Module Reader:** **[Module 2: The Reports Pipeline & Its Tuning](./module-02/course.md)**
    1. [The Reports Pipeline](./module-02/course-01-the-reports-pipeline.md)
    2. [Tuning and Troubleshooting Reports](./module-02/course-02-tuning-and-troubleshooting-reports.md)
*   **Practice Lab Sandbox:** **`sections/section-010/module-02/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-02/labs/lab-01
    ```
*   **Hands-on Objective:** Force a pre-existing, policy-violating Deployment into a `PolicyReport` by lowering the background scan interval, then prove you understand the difference between the admission path and the background path by producing a finding through each.

### 3. Section Capstone Challenge
*   **Comprehensive Challenge:** **`sections/section-010/capstone/labs/lab-01` (Policy Reports Integration)**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-010/capstone/labs/lab-01
    ```
*   **Hands-on Objective:** Run a scored policy and an advisory (`scored: "false"`) policy side by side over two namespaces, tune the reports controller so pre-existing workloads are scanned on a lab-friendly schedule, and produce a report state where `fail`, `warn`, and `pass` are each provably present in the right place.

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the practical lab missions:

*   **[Take the Section 010 Knowledge Check Quiz](./quiz.md)**
