# Section 010 Knowledge Check: Policy Reports

Test your understanding of the `PolicyReport`/`ClusterPolicyReport` model, report naming and structure, the five result types, the two report-producing paths, and the flags that tune them.

---

## Scenario-Based Questions

### Question 1
A `ClusterPolicy` evaluates `Namespace` resources and records a violation on the `finance` namespace. Where does that finding land?
*   **A)** In a `PolicyReport` inside the `finance` namespace, because that is the resource involved.
*   **B)** In a `ClusterPolicyReport`, because `Namespace` is a cluster-scoped resource — the report kind follows the resource, not the policy.
*   **C)** In a `PolicyReport` inside the `kyverno` namespace, where all cluster-level findings are collected.
*   **D)** In both a `PolicyReport` and a `ClusterPolicyReport`, mirrored.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The choice between `PolicyReport` and `ClusterPolicyReport` is determined by the scope of the *reported resource*. A `Namespace` is cluster-scoped, so its findings go into a `ClusterPolicyReport`, even though a namespace "contains" things.
*   **Why others are incorrect:**
    *   *Option A* applies the rule to the wrong object — `finance` here is the resource being judged, not a namespace the resource lives in.
    *   *Option C* invents a central collection namespace; Kyverno does not funnel findings into `kyverno`.
    *   *Option D* invents duplication that does not happen — each finding is recorded once.
</details>

---

### Question 2
`kubectl get polr -A` returns reports whose names are UUIDs like `487df031-11d8-4ab4-b089-dfc0db1e533e`. What is that UUID?
*   **A)** A random identifier assigned per scan cycle.
*   **B)** The `metadata.uid` of the resource the report describes — modern Kyverno keeps one report per resource.
*   **C)** The UID of the `ClusterPolicy` that produced the finding.
*   **D)** A hash of the policy name plus the namespace name.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Since Kyverno 1.10 reports are stored per-resource and named after the reported resource's UID, with an `ownerReferences` entry back to that resource so the report is garbage-collected when the resource is deleted. You find a report by the `KIND`/`NAME` printer columns or via the resource's UID, never by guessing a name.
*   **Why others are incorrect:**
    *   *Option A* would break the owner-reference and garbage-collection model, and would produce a new object every cycle.
    *   *Option C* is backwards — one report holds results from every policy that evaluated that one resource.
    *   *Option D* describes the pre-1.10 aggregated naming idea, which was `polr-ns-<namespace>`, not a hash.
</details>

---

### Question 3
A report entry reads `result: skip`. What does that tell you?
*   **A)** The rule did not match the resource, so nothing was evaluated.
*   **B)** The rule matched but was deliberately not applied — a precondition was false, a conditional anchor's condition was unmet, or a `PolicyException` exempted the resource.
*   **C)** Kyverno could not evaluate the rule because of an internal error.
*   **D)** The resource passed, but the policy is advisory.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `skip` is a positive statement that the rule *did* apply to this resource and was then deliberately not enforced. When the cause is a `PolicyException`, the entry also carries `properties.exceptions` naming the exception — which is exactly what makes exemptions auditable.
*   **Why others are incorrect:**
    *   *Option A* describes the case that produces **no result entry at all**; a non-matching resource simply never appears for that rule.
    *   *Option C* describes `error`.
    *   *Option D* describes `warn` — the advisory downgrade caused by `policies.kyverno.io/scored: "false"`.
</details>

---

### Question 4
Your CI gate fails a build when `summary.fail > 0` in any `PolicyReport`. A policy is clearly being violated by dozens of workloads, but the gate never trips. What should you check first?
*   **A)** Whether the policy has `validationFailureAction: Enforce`.
*   **B)** Whether the policy carries `policies.kyverno.io/scored: "false"`, which converts every failure into a `warn` and leaves `summary.fail` at zero.
*   **C)** Whether background scanning is enabled on the cluster.
*   **D)** Whether the reports CRDs are installed.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `scored: "false"` marks a policy as advisory. Its violations are still recorded, but as `warn`, so `summary.warn` climbs while `summary.fail` stays at zero. A gate written only against `fail` will never see them.
*   **Why others are incorrect:**
    *   *Option A* is irrelevant — `Enforce` vs `Audit` changes whether the resource is admitted, not which counter a recorded failure increments.
    *   *Option C* would produce no report entries at all, not entries with a zero `fail` counter, and the question states violations are visible.
    *   *Option D* would mean no reports exist whatsoever.
</details>

---

### Question 5
You apply an `Audit` policy to a cluster. A Pod created immediately afterwards shows up in a report within seconds, but a Deployment that has been running for months does not appear at all. Nothing is misconfigured. Why?
*   **A)** Background scanning only covers Pods, never Deployments.
*   **B)** The new Pod went through the admission path (immediate); the old Deployment can only be seen by a background scan, which runs every `--backgroundScanInterval` — one hour by default.
*   **C)** Reports are only generated for resources created after the reports controller last restarted.
*   **D)** `Audit` mode disables reporting for pre-existing resources.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** There are two independent producers of report data on two different clocks. The admission controller records findings as part of handling a live request, so new violations appear almost at once. Pre-existing resources generate no admission request, so they wait for the reports controller's periodic background scan — `--backgroundScanInterval`, default `1h`.
*   **Why others are incorrect:**
    *   *Option A* invents a kind restriction that does not exist.
    *   *Option C* is wrong — background scans cover everything matching, regardless of creation time.
    *   *Option D* is backwards; `Audit` mode is precisely the mode whose whole output *is* reports.
</details>

---

### Question 6
Which controller owns the periodic background scan that produces report data for already-existing resources?
*   **A)** `kyverno-background-controller`, as the name suggests.
*   **B)** `kyverno-reports-controller` — the background controller owns `generate` and `mutateExisting` rules, not report scanning.
*   **C)** `kyverno-admission-controller`, which handles all policy evaluation.
*   **D)** `kyverno-cleanup-controller`.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Despite the naming collision, background *scanning for reports* belongs to `kyverno-reports-controller` — it carries `--backgroundScan`, `--backgroundScanInterval` and `--backgroundScanWorkers`. The `kyverno-background-controller` handles `generate` and `mutateExisting` rules, which create and patch resources.
*   **Why others are incorrect:**
    *   *Option A* is the trap the name sets; checking which Deployment actually carries the `--backgroundScanInterval` flag settles it.
    *   *Option C* handles the live admission path only.
    *   *Option D* owns `CleanupPolicy` and TTL-based deletion.
</details>

---

### Question 7
What is an `EphemeralReport`, and how should you treat it?
*   **A)** The final, stable report object — read it directly in dashboards.
*   **B)** A short-lived intermediate object that either controller writes findings into, which the reports controller then aggregates into a `PolicyReport` and deletes. It is internal plumbing and should not be built against.
*   **C)** A report for Pods that have already been deleted.
*   **D)** A cached copy of a `PolicyReport` kept for performance.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `ephemeralreports.reports.kyverno.io` (and its cluster-scoped twin) are the staging area that lets the admission controller and the reports controller both produce findings without fighting over one `PolicyReport` object. The reports controller merges them into the stable `wgpolicyk8s.io` report and deletes the ephemeral object. Their schema and behaviour are internal and may change between versions.
*   **Why others are incorrect:**
    *   *Option A* names the wrong object as stable — `polr`/`cpolr` are the stable API.
    *   *Option C* invents a purpose; reports are garbage-collected with their resource.
    *   *Option D* is wrong — it is a write-side staging area, not a read cache.
</details>

---

### Question 8
You add `[*/*,noisy-ns,*]` to `resourceFilters` in the `kyverno` ConfigMap, but `PolicyReport` objects keep appearing in `noisy-ns`. What is going on?
*   **A)** `resourceFilters` needs a controller restart before it takes effect at all.
*   **B)** The reports controller runs with `--skipResourceFilters=true` by default, so background scans deliberately ignore `resourceFilters`; set it to `false` to make the filter apply to reporting too.
*   **C)** `resourceFilters` only accepts `[kind,name]` pairs, so the entry is invalid.
*   **D)** Reports are never affected by any configuration — they always cover every resource.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `--skipResourceFilters` on `kyverno-reports-controller` defaults to `true`, meaning background scanning skips *applying* the filters. The design intent is that a performance exclusion at the admission webhook should not silently blind compliance reporting. Setting `--skipResourceFilters=false` makes background scans obey `resourceFilters`.
*   **Why others are incorrect:**
    *   *Option A* is wrong — the ConfigMap is watched, and a restart would not change the flag's behaviour anyway.
    *   *Option C* misstates the format, which is `[kind,namespace,name]`.
    *   *Option D* is wrong — `--enableReporting`, `--policyReports` and `--skipResourceFilters` all shape what gets reported.
</details>

---

### Question 9
A `ClusterPolicy` is applied with `spec.background: false`, and a Deployment that existed before it violates one of its rules. What appears in the reports?
*   **A)** A `fail` entry once the next background scan runs.
*   **B)** Nothing for that pre-existing Deployment, ever — `spec.background: false` means the policy is only evaluated at admission time.
*   **C)** A `skip` entry, recording that background evaluation was disabled.
*   **D)** An `error` entry, because the rule cannot be evaluated outside admission.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `background` is a policy-level field (`spec.background`, default `true`). Setting it to `false` opts the whole policy out of periodic re-scanning. The pre-existing resource generates no admission request, and the background scan will not look at it, so no result entry is ever produced for that pairing. This is by design and is the correct setting for a policy whose rules inspect request-specific context such as `request.userInfo`.
*   **Why others are incorrect:**
    *   *Option A* describes `spec.background: true`.
    *   *Option C* misuses `skip`, which records a rule that matched and was deliberately not enforced.
    *   *Option D* misuses `error`, which records a failed evaluation such as a broken variable substitution.
</details>

---

### Question 10
Your reports are consistently an hour stale, the reports controller's CPU is saturated, and a single scan cycle is taking longer than the interval between cycles. Which change addresses the actual problem?
*   **A)** Lower `--backgroundScanInterval` so scans start more often.
*   **B)** Raise `--backgroundScanWorkers` so each scan cycle completes faster, then reassess the interval.
*   **C)** Set `--policyReports=false` to stop generating reports.
*   **D)** Delete the accumulated `PolicyReport` objects to free memory.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The symptom is a scan that cannot finish within its own cycle. `--backgroundScanWorkers` (default `2`) controls how many worker threads process a scan, so raising it is the lever that makes a cycle complete faster. Only once cycles finish comfortably does changing the interval make sense.
*   **Why others are incorrect:**
    *   *Option A* makes it strictly worse: starting cycles more often on a controller that cannot finish one is how you build a permanent backlog.
    *   *Option C* disables the reporting system rather than fixing it.
    *   *Option D* treats a symptom — reports are owned by their resources and are recreated on the next scan.
</details>
