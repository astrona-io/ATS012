# Question

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this question on: `terminal`

The Kyverno CLI v1.13.2 is installed. The directory `/opt/kyverno-capstone` holds two policies and `resources.yaml`:

*   `disallow-latest.yaml` - validate rule `check-tag` in the policy `disallow-latest-tag`;
*   `add-team-label.yaml` - mutate rule `add-team` in the policy `add-team-label`, which adds the label `team: platform` to Pods that have the label `app: web`;
*   `resources.yaml` - the Pods `web` (image `nginx:1.27`, label `app: web`) and `legacy` (image `nginx:latest`, no labels).

Do not change the policies or `resources.yaml`.

1.  Create `/opt/kyverno-capstone/kyverno-test.yaml` as a `Test` (`cli.kyverno.io/v1alpha1`) that lists both policies and the resources, and expects:
    *   `check-tag` passes for `web`;
    *   `check-tag` fails for `legacy`;
    *   `add-team` applies to `web` and produces the Pod in a file you write, referenced with `patchedResource`.
2.  Create `/opt/kyverno-capstone/run-tests.sh` that runs `kyverno test` on the directory and uses its exit code, so a pipeline can stop on a failure.
3.  Make `bash /opt/kyverno-capstone/run-tests.sh` exit with code 0. The test must fail if someone changes the label value in the mutate policy.
