# Summary

Every Kyverno controller serves Prometheus text on port 8000 at `/metrics`. Knowing which Service to scrape and which family answers which question is most of the skill.

## What you learned

Four metrics Services front the four controllers: the admission controller's is `kyverno-svc-metrics`, and the others follow the controller name. The flags `--disableMetrics`, `--metricsPort` and `--otelConfig` control whether and how metrics are exposed. The six families to know are `kyverno_policy_results_total` (outcomes per policy and rule), `kyverno_policy_rule_info_total` (a gauge, value 1 per rule that exists), `kyverno_admission_requests_total`, `kyverno_admission_review_duration_seconds`, `kyverno_policy_execution_duration_seconds` and `kyverno_policy_changes_total`. The docs name counters without `_total`; the exporter adds it, and PromQL must use the exported name. `rule_execution_cause` separates admission traffic from background scans.

The key facts to remember are these:

- Port 8000, path `/metrics`, one Service per controller.
- Use the exported name with `_total`.
- Do not `rate()` a gauge such as `kyverno_policy_rule_info_total`.
- Metrics aggregate; they carry no per-resource label by default.

<!-- astrona:playground:destroy -->
