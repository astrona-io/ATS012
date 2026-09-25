# ATS012 - KCA: Policy Management

[![Liberapay](https://img.shields.io/badge/Liberapay-Support_Astrona.io-F6C915?logo=liberapay&logoColor=black&style=for-the-badge)](https://liberapay.com/Astrona.io)

Welcome to **ATS012**, a free, hands-on training curriculum built around the **Policy Management** domain — the competencies a **Kyverno Certified Associate (KCA)** learner needs to operate a policy estate after the policies are written and applied: reading what Kyverno found, granting auditable exemptions, and watching the engine's own health through its metrics. This is community training material inspired by the open-source [Kyverno project](https://kyverno.io) (a CNCF Sandbox project); it is not an official Linux Foundation or CNCF exam guide, and no specific vendor exam blueprint is claimed or implied.

Applying a policy is where enforcement starts, not where the job ends. This repository covers the operational half: the `PolicyReport` objects that tell you what is non-compliant, the `PolicyException` objects that let you say "yes, we know, and it is allowed here", and the Prometheus metrics that tell you whether Kyverno itself is keeping up.

Every lab in this repository is pinned to **Kyverno v1.13.2** so that flag names, CRD versions, and default settings match exactly what you see on screen.

---

## The Symmetrical 1:1:1 Learning Framework

To make learning intuitive, digestible, and robust, this curriculum is built around a symmetrical **1:1:1 educational architecture**:

1.  **The Textbook Lesson (`sections/section-XXX/module-YY/course.md`):** Narrative, book-style chapters written in a warm, expert "teacher's voice" that explain *why* Kyverno behaves the way it does, using real-world metaphors, inline YAML breakdowns, and clear diagrams.
2.  **The Interactive Quiz (`sections/section-XXX/quiz.md`):** A scenario-based theoretical knowledge check testing diagnostic reasoning, complete with collapsible answers and technical explanation keys.
3.  **The Dedicated Laboratory (`sections/section-XXX/module-YY/labs/lab-01`, plus a `sections/section-XXX/capstone/` per section):** A live **kind** Kubernetes cluster sandbox launched instantly via the `astrona` CLI, where you operate a real Kyverno installation and validate your cluster's state using automated grading scripts.

---

## Complete Curriculum & Lab Mapping

The training series is divided into **3 main sections** covering **6 focused modules**, **6 graded module labs**, and **3 comprehensive Section Capstone Challenges**:

| Section & Domain | Module & Chapter Reader | Practice Lab | astrona CLI Run Command |
| :--- | :--- | :--- | :--- |
| **010: Policy Reports** | [M1: Reading PolicyReports](sections/section-010/module-01/course.md) | [lab](sections/section-010/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-01/labs/lab-01` |
| | [M2: The Reports Pipeline & Its Tuning](sections/section-010/module-02/course.md) | [lab](sections/section-010/module-02/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-02/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-010/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-010/capstone/labs/lab-01` |
| **020: PolicyExceptions** | [M1: Enabling & Writing a PolicyException](sections/section-020/module-01/course.md) | [lab](sections/section-020/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-01/labs/lab-01` |
| | [M2: Narrowing, Governing & Auditing Exceptions](sections/section-020/module-02/course.md) | [lab](sections/section-020/module-02/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-02/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-020/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-020/capstone/labs/lab-01` |
| **030: Kyverno Metrics** | [M1: The Metrics Endpoint & Core Metric Families](sections/section-030/module-01/course.md) | [lab](sections/section-030/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-01/labs/lab-01` |
| | [M2: Configuring Metrics & Controlling Cardinality](sections/section-030/module-02/course.md) | [lab](sections/section-030/module-02/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/module-02/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-030/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-030/capstone/labs/lab-01` |

---

## How to Navigate This Course

1.  **Enter a Domain Portal:** Navigate into a domain directory, such as `sections/section-010/`, and open its `README.md` to review the section's core competencies.
2.  **Read the Chapters:** Open and read the narrative chapters in order (`module-01/course.md`, `module-02/course.md`, …). Focus on the diagrams, YAML breakdowns, and "Try it" checkpoints.
3.  **Take the Chapter Self-Check:** Challenge yourself with the conceptual questions at the bottom of each course module.
4.  **Test Your Diagnostics:** Open `quiz.md` inside that section and answer its scenario questions. Expand the `<details>` tags to read the teacher's deep-dive explanations.
5.  **Practice the Sandboxes:** Run the module labs (e.g., `sections/section-010/module-01/labs/lab-01`) on a live kind cluster to build real operational muscle memory.
6.  **Conquer the Capstone Challenges:** Boot up the section's **Capstone Challenge Lab**, solve the integration prompts, and run the automated validation suite to confirm your passing state.
7.  **Simulate the Exam:** Once you have completed all 6 modules, open **`sections/final-domain-quiz.md`** and complete the final closed-book domain exam simulator under a time cap to audit your readiness.

---

## Cluster-Native Focus

Every lab in this repository runs on a **kind** (Kubernetes-in-Docker) cluster spun up by the `astrona` CLI — there are no virtual machines, no host-level Linux administration, and no QEMU images. You work exclusively through `kubectl` against a real Kyverno installation, exactly as you would against a production cluster.

---

## Support This Project

ATS012 is free Kyverno training material. If it helped you on your policy-engine journey, consider supporting ongoing work and resource development via [Liberapay](https://liberapay.com/Astrona.io).
