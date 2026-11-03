# Question

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this question on: `terminal`

The Kyverno CLI v1.13.2 is installed. The directory `/opt/kyverno-lab` holds the policy `require-limits` (rule `check-limits`) in `policy.yaml`, and two Pods in `resources.yaml`: `good-pod` sets CPU and memory limits and `bad-pod` sets none. Do not change `policy.yaml` or `resources.yaml`.

1.  Run `kyverno apply` on the policy and the resources and find which Pod fails.
2.  Create `/opt/kyverno-lab/kyverno-test.yaml` as a `Test` (`cli.kyverno.io/v1alpha1`) that lists `policy.yaml` and `resources.yaml` and expects:
    *   `pass` for `good-pod`;
    *   `fail` for `bad-pod`.
3.  Run `kyverno test /opt/kyverno-lab` and make it exit with code 0.
