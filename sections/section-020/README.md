# Section 020: PolicyExceptions

Welcome to the second domain in Policy Management. Every real cluster eventually contains a workload that a correct policy is wrong about. How you handle that one workload decides whether your policy estate stays trustworthy or slowly rots into a set of rules with undocumented holes.

Kyverno's answer is the `PolicyException` — a separate, named, namespaced object that waives specific rules for specific resources, shows up in your reports as an auditable `skip`, and can be governed with ordinary RBAC. This section covers turning the feature on safely, writing exceptions that are as narrow as the problem, and running them as a governed process rather than an ad-hoc escape hatch.

---

## What You Will Master

By completing this section, you will acquire two core Policy Management competencies:
*   **Enabling & Authoring Exceptions:** Why the feature ships disabled, what `--enablePolicyException` and `--exceptionNamespace` each control, which of Kyverno's controllers need them and what breaks when only some do, and every field of a `kyverno.io/v2` `PolicyException` — including the `autogen-` rule-name trap that catches everyone once.
*   **Narrowing & Governing Exceptions:** `conditions` for a live opt-in gate, `podSecurity` for waiving a single Pod Security Standards control instead of a whole rule, `background` for keeping reports and enforcement in agreement, the decision between an exception and an `exclude` block, RBAC over the exception namespace, validating exceptions with a policy of their own, and auditing what is *actually* exempted from the reports.

---

## The Learning & Lab Path

This section is divided into two sequential modules, each paired with a dedicated graded lab on a kind Kubernetes cluster. The section concludes with a comprehensive Capstone Integration Challenge:

### 1. Enabling & Writing a PolicyException
*   **Module Reader:** **[Module 1: Enabling & Writing a PolicyException](./module-01/course.md)**
    1. [Enabling PolicyExceptions](./module-01/course-01-enabling-policyexceptions.md)
    2. [The Anatomy of a PolicyException](./module-01/course-02-anatomy-of-a-policyexception.md)
*   **Practice Lab Sandbox:** **`sections/section-020/module-01/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-01/labs/lab-01
    ```
*   **Hands-on Objective:** Take an `Enforce` policy that is blocking a legacy Deployment, enable exceptions on both the admission controller and the reports controller, and write an exception that lets exactly that workload through — then prove the report changed from `fail` to `skip` and names your exception.

### 2. Narrowing, Governing & Auditing Exceptions
*   **Module Reader:** **[Module 2: Narrowing, Governing & Auditing Exceptions](./module-02/course.md)**
    1. [Narrowing an Exception: conditions, podSecurity & background](./module-02/course-01-conditions-podsecurity-and-background.md)
    2. [Governance, Alternatives & Auditing](./module-02/course-02-governance-and-alternatives.md)
*   **Practice Lab Sandbox:** **`sections/section-020/module-02/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-02/labs/lab-01
    ```
*   **Hands-on Objective:** Replace a broad name-based exemption with a `conditions`-gated one that requires each workload to opt in by label, prove an un-labelled workload is still blocked, and stop sloppy exceptions at the door with a policy that validates `PolicyException` objects themselves.

### 3. Section Capstone Challenge
*   **Comprehensive Challenge:** **`sections/section-020/capstone/labs/lab-01` (PolicyExceptions Integration)**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-020/capstone/labs/lab-01
    ```
*   **Hands-on Objective:** Run a governed exception process end to end — feature enabled and scoped to one namespace, a hygiene policy forcing owner and expiry metadata on every exception, a narrow condition-gated exemption that works, and a second exception in the wrong namespace that provably does nothing.

---

## Ready for Assessment?

Test your theoretical knowledge and diagnostic reasoning before tackling the practical lab missions:

*   **[Take the Section 020 Knowledge Check Quiz](./quiz.md)**
