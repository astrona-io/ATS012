# Section 020 Knowledge Check: PolicyExceptions

Test your understanding of enabling PolicyExceptions, the object's fields, the autogen rule-name trap, narrowing with `conditions` and `podSecurity`, and the governance model around exemptions.

---

## Scenario-Based Questions

### Question 1
You create a `PolicyException` on a freshly installed Kyverno v1.13.2 cluster. `kubectl get policyexception` shows it, but the policy keeps blocking the workload. What is the most likely cause?
*   **A)** The exception needs several minutes to propagate to the webhook.
*   **B)** PolicyExceptions are disabled by default; `--enablePolicyException=true` must be set on the controllers, along with a matching `--exceptionNamespace`.
*   **C)** `PolicyException` only works against namespaced `Policy` objects, never `ClusterPolicy`.
*   **D)** The exception must be created in the `kyverno` namespace.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The CRD is installed by default but the feature is off. Without `--enablePolicyException=true`, the object is stored happily by the API server and has no effect whatsoever — no error, no event, no warning. `--exceptionNamespace` then restricts which namespace's exceptions are honoured.
*   **Why others are incorrect:**
    *   *Option A* invents a propagation delay; once the feature is on, exceptions apply immediately.
    *   *Option C* is wrong — exceptions work against both, with `<namespace>/<name>` used in `policyName` for a namespaced `Policy`.
    *   *Option D* is wrong — the exception must live in the namespace `--exceptionNamespace` names, which is a namespace you choose, not `kyverno` by default.
</details>

---

### Question 2
You enable exceptions on `kyverno-admission-controller` only. Your exempted Deployment now deploys successfully, but your compliance dashboard still shows it failing. Why?
*   **A)** The dashboard is caching stale data.
*   **B)** The reports controller also needs `--enablePolicyException=true`; without it, background scans do not honour the exception and keep recording `fail` instead of `skip`.
*   **C)** Reports always record the pre-exception result for audit purposes.
*   **D)** Exceptions never affect reports, by design.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Three controllers carry the flag and each applies it to its own work: the admission controller decides whether the resource is admitted, the reports controller decides whether a background scan records `skip`, and the background controller applies it to `generate`/`mutateExisting` processing. Setting it on only one produces exactly this enforcement-versus-record mismatch.
*   **Why others are incorrect:**
    *   *Option A* is a guess that does not explain a reproducible mismatch.
    *   *Option C* invents a "record the original verdict" behaviour that does not exist.
    *   *Option D* is contradicted by `result: skip` and the `properties.exceptions` field.
</details>

---

### Question 3
A `ClusterPolicy` has exactly one rule, named `check-limits`, matching `kinds: [Pod]`. A Deployment is being blocked by it. Your exception lists `ruleNames: [check-limits]` and matches `kinds: [Pod]`. Why does the Deployment stay blocked?
*   **A)** Exceptions cannot exempt Deployments at all.
*   **B)** Autogen generates a parallel `autogen-check-limits` rule for Pod-owning controllers, and it is that rule blocking the Deployment request — the exception must name it and match `kind: Deployment`.
*   **C)** `ruleNames` requires a wildcard to work.
*   **D)** The Deployment must be annotated to accept exceptions.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** Kyverno's autogen mechanism silently adds `autogen-`-prefixed copies of a Pod-scoped rule for Deployment, StatefulSet, DaemonSet, Job, CronJob and ReplicaSet. The admission request being rejected is the `Deployment` request, evaluated by `autogen-check-limits`. An exception must therefore list both rule names and match the `Deployment` kind as well as `Pod`.
*   **Why others are incorrect:**
    *   *Option A* is wrong — exceptions match any kind the underlying rule reaches.
    *   *Option C* is wrong; a wildcard would work but only because it happens to cover the autogen name — naming both rules explicitly is the precise fix.
    *   *Option D* invents an opt-in annotation on the workload that Kyverno does not require.
</details>

---

### Question 4
An exception matches `names: ["legacy-api"]` exactly. The Deployment is admitted, but its Pods still produce failing results. What went wrong?
*   **A)** Pods are never covered by exceptions.
*   **B)** The Pods are named `legacy-api-<replicaset-hash>-<pod-hash>`, which does not match the exact name; a prefix wildcard like `legacy-api*` is needed.
*   **C)** Pod-level exemptions require a separate exception object.
*   **D)** `names` only accepts a single entry.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** A Deployment's Pods carry generated suffixes from the ReplicaSet, so an exact-name match covers the controller but none of the Pods it spawns. `names: ["legacy-api*"]` covers both.
*   **Why others are incorrect:**
    *   *Option A* and *Option C* invent restrictions that do not exist — one exception can match several kinds.
    *   *Option D* is wrong; `names` is a list.
</details>

---

### Question 5
What does a `conditions` block on a `PolicyException` add that tightening `match` does not?
*   **A)** Nothing — they are two syntaxes for the same test.
*   **B)** A second, independent gate evaluated against live request data, so the resource itself must opt in (for example by carrying a specific label) rather than the exemption being decided purely by the exception's own definition.
*   **C)** It makes the exception apply to cluster-scoped resources.
*   **D)** It delays the exemption until the next background scan.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `match` selects candidates by identity; `conditions` applies `any`/`all` key/operator/value tests with JMESPath substitution against the request. The useful consequence is that the exempted workload's own manifest shows it claiming the exemption, which is a far better review artifact than a name buried in an exception object elsewhere.
*   **Why others are incorrect:**
    *   *Option A* ignores that one is identity-based selection and the other is live data evaluation.
    *   *Option C* is unrelated — exceptions already exempt cluster-scoped resources.
    *   *Option D* invents timing behaviour; `spec.background` is the field that touches scanning.
</details>

---

### Question 6
A Pod Security Standards policy blocks a monitoring agent that legitimately needs host namespaces. What is the most surgical exemption?
*   **A)** Waive the whole `baseline` rule for the `monitoring` namespace.
*   **B)** Use `spec.podSecurity` with `controlName: "Host Namespaces"` and an `images` entry for that agent's image, leaving every other control enforcing.
*   **C)** Delete the policy and re-apply it with the namespace excluded.
*   **D)** Set `validationFailureAction: Audit` on the policy.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** A `podSecurity` exemption waives one named control from a Pod Security Standards rule, optionally narrowed to specific images and, with `restrictedField`/`values`, to specific field values. Every other control in the rule keeps enforcing on that same Pod.
*   **Why others are incorrect:**
    *   *Option A* waives dozens of unrelated controls to solve one problem.
    *   *Option C* removes enforcement from an entire namespace permanently and leaves no audit trail.
    *   *Option D* turns off blocking for the whole cluster, not for one agent.
</details>

---

### Question 7
A policy is intended never to apply to `kube-system`. What is the right mechanism?
*   **A)** A `PolicyException` in the exception namespace covering `kube-system`.
*   **B)** An `exclude` block in the policy — this is the policy's actual scope, not a tolerated deviation.
*   **C)** Either; they are equivalent.
*   **D)** Remove `kube-system` from the cluster's `resourceFilters`.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** `exclude` expresses what the policy permanently does not mean; a `PolicyException` expresses a deviation you are temporarily willing to tolerate and expect to revisit. Scope belongs in the policy.
*   **Why others are incorrect:**
    *   *Option A* creates a permanent "temporary" exemption and adds a governed object where a scope statement belongs.
    *   *Option C* ignores that the two differ in ownership, lifetime, RBAC surface, and whether findings appear in reports at all.
    *   *Option D* is backwards — a stock install already filters `kube-system`, and removing it would *increase* processing there.
</details>

---

### Question 8
You enable `--enablePolicyException=true` but leave `--exceptionNamespace` unset. What is the resulting posture?
*   **A)** Exceptions are honoured from every namespace, so anyone who can create objects in their own namespace can waive rules for their own workloads.
*   **B)** Exceptions are honoured only from the `default` namespace.
*   **C)** Exceptions are silently ignored until the flag is set.
*   **D)** Kyverno refuses to start.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: A**

*   **Why A is correct:** `--exceptionNamespace` is what restricts where exceptions are honoured from. Without it, the feature is cluster-wide, which converts an enforcement boundary into an opt-out available to anyone with namespace-level create permissions.
*   **Why others are incorrect:**
    *   *Option B* invents a default namespace fallback.
    *   *Option C* describes the behaviour when the feature flag itself is `false`.
    *   *Option D* is wrong — the configuration is valid, just dangerously broad.
</details>

---

### Question 9
`kubectl get policyexception -A` lists six exceptions. How many exemptions are actually in effect?
*   **A)** Six — each object is one exemption.
*   **B)** Unknown from that command alone. Nothing validates `policyName` or `ruleNames` against real policies, and exceptions outside `--exceptionNamespace` are ignored; the reports' `skip` results with `properties.exceptions` show what is really being waived.
*   **C)** Zero until each is approved by the admission controller.
*   **D)** Six, minus any that are older than their `expires` annotation.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** An exception with a typo in `policyName`, a missing `autogen-` rule name, or the wrong namespace is a perfectly valid object that waives nothing. The authoritative view of live exemptions is the reports: every `skip` result carries `properties.exceptions` naming the exception responsible.
*   **Why others are incorrect:**
    *   *Option A* confuses intent with effect.
    *   *Option C* invents an approval step.
    *   *Option D* assumes Kyverno interprets an `expires` annotation, which is a convention you enforce yourself with a policy and a cleanup policy — nothing built in.
</details>

---

### Question 10
Why would you write a Kyverno `ClusterPolicy` that validates `PolicyException` resources with `background: false`?
*   **A)** Because policies over Kyverno's own CRDs cannot be background-scanned.
*   **B)** Because the rule checks the shape of an exception at creation time — requiring, say, owner and expiry annotations — and re-scanning existing exceptions hourly adds load without adding information.
*   **C)** Because background scanning would delete non-compliant exceptions.
*   **D)** Because `PolicyException` objects are cluster-scoped.

<details>
<summary><b>Reveal Correct Answer & Teacher's Explanation</b></summary>

**Correct Answer: B**

*   **Why B is correct:** The value of a hygiene policy over exceptions is blocking a badly-formed exception at admission. Periodic re-evaluation of already-accepted exceptions produces the same verdict every cycle, so `background: false` trims cost without losing anything.
*   **Why others are incorrect:**
    *   *Option A* is wrong — Kyverno can evaluate its own CRDs, and background scans over them work.
    *   *Option C* is wrong — background scans never delete anything; they only report.
    *   *Option D* is factually wrong: `PolicyException` is namespaced.
</details>
