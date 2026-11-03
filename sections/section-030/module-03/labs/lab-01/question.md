# Question

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this question on: `terminal`

Kyverno v1.13.2 is installed. The namespace `load-ns` exists, the Pod `metrics-probe` in `default` has `curl`, and the `ClusterPolicy` `load-require-limits` is live in `Enforce` mode for Pods in `load-ns`. No load has been generated yet. The metrics Service is `kyverno-svc-metrics` on port `8000` in namespace `kyverno`.

1.  Generate load in `load-ns`: create three Pods that set CPU and memory limits (they are admitted) and two Pods that set none (they are rejected). Use any names. The rejected Pods must not exist afterwards.
2.  Scrape `http://kyverno-svc-metrics.kyverno.svc:8000/metrics` from `metrics-probe`. Find the figures below for the policy `load-require-limits`, counting only results whose `rule_execution_cause` is `admission_request`:
    *   the total of `kyverno_policy_results_total` with `rule_result="pass"`;
    *   the total of `kyverno_policy_results_total` with `rule_result="fail"`;
    *   the total of `kyverno_admission_review_duration_seconds_count` over all its series.
3.  Record them in a ConfigMap `metrics-findings` in `load-ns` with the keys `pass-total`, `fail-total` and `admission-review-count`, each a whole number.
4.  Write an alert in the shape of a `PrometheusRule` and store it as the key `rule.yaml` in a ConfigMap `kyverno-alert-rule` in `load-ns`. The Prometheus Operator is not installed, so you only store the text. The rule must:
    *   define an alert named `KyvernoPolicyViolations`;
    *   use an `expr` that wraps `kyverno_policy_results_total{rule_result="fail"}` in `increase(` or `rate(`, so a Kyverno restart does not break it;
    *   have a `for:` duration;
    *   set a `severity` label.
