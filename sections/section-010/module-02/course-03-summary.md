# Summary

Report data has two producers on two clocks, and the flags on the reports controller decide how fast and how widely it is produced.

## What you learned

The admission controller records a finding while it handles a live request, so new violations appear within seconds. Pre-existing resources produce no admission request, so they wait for the background scan owned by `kyverno-reports-controller`. The `kyverno-background-controller` is a different component: it owns `generate` and `mutateExisting` rules. Both producers write `EphemeralReport` objects as internal staging, and the reports controller merges them into the stable `PolicyReport` and `ClusterPolicyReport`. Never build tooling on `EphemeralReport`.

`--backgroundScanInterval` (default `1h`) sets the scan clock, `--backgroundScanWorkers` (default `2`) sets how fast one cycle finishes, and `--enableReporting` chooses which rule types are reported. A policy with `spec.background: false` is never rescanned. `resourceFilters` is not applied to background scans unless `--skipResourceFilters=false` is set on the reports controller.

The key facts to remember are these:

- Admission path is immediate; the background path waits for the scan interval.
- Raise workers before you lower the interval when a cycle cannot finish.
- `resourceFilters` needs `--skipResourceFilters=false` to affect reports.
- Diagnose a missing report in order: is the policy matching, is background enabled, is the controller healthy, is the resource filtered.

<!-- astrona:playground:destroy -->
