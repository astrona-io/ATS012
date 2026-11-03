# Section 040: Policy Testing with the Kyverno CLI

Sections 010 to 030 covered what happens after a policy reaches a cluster: reports, exceptions and metrics. This section covers the step before. The Kyverno CLI evaluates a policy against resource files on your machine, so you can prove what a policy does and stop a wrong change in a pull request.

---

## What You Will Master

*   **Running a policy locally:** `kyverno apply`, its result counts, exit behavior and the flags that change its output.
*   **Writing tests:** `kyverno-test.yaml`, expected results per policy, rule and resource, values files, user information, `patchedResource` and `generatedResource`.
*   **Automating tests:** exit codes, test selection, pinned CLI versions and repository layout.

---

## The Learning & Lab Path

### 1. Testing Policies with the Kyverno CLI
*   **Module Reader:** **[Module 1: Testing Policies with the Kyverno CLI](./module-01/course.md)**
    1. [Running a Policy with kyverno apply](./module-01/course-01-running-a-policy-with-kyverno-apply.md)
    2. [Writing kyverno-test.yaml](./module-01/course-02-writing-kyverno-test-yaml.md)
    3. [Variables, Mutate and Generate Tests](./module-01/course-03-variables-mutate-and-generate-tests.md)
    4. [Running Tests in CI](./module-01/course-04-running-tests-in-ci.md)
    5. [Summary](./module-01/course-05-summary.md)
*   **Playground:** ungraded, `sections/section-040/module-01/playground`; launched from the module reader.
*   **Practice Lab Sandbox (UNTESTED):** **`sections/section-040/module-01/labs/lab-01`**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-040/module-01/labs/lab-01
    ```
*   **Hands-on Objective:** Run a policy on two Pods and write the `kyverno-test.yaml` that expects a pass and a fail.

### 2. Section Capstone Challenge
*   **Comprehensive Challenge:** **`sections/section-040/capstone/labs/lab-01` (Policy Testing)**
*   **Lab Run Command:**
    ```bash
    astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-040/capstone/labs/lab-01
    ```
*   **Hands-on Objective:** Test a validate rule and a mutate rule, and write a runner that fails when the mutate policy is wrong.

---

## Ready for Assessment?

*   **[Take the Section 040 Knowledge Check Quiz](./quiz.yaml)**
