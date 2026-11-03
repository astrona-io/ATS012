# Part 4 — Reports in Automation and the Kyverno CLI

Reports are plain Kubernetes objects, so a script can read them the same way a person does. This part covers two uses: a gate that fails a pipeline when a namespace has violations, and the Kyverno command line tool (CLI), which produces a report from a file on disk without a cluster.

## Count failures with jq

`jq` is a command line JSON processor. Ask `kubectl` for JSON and let `jq` do the counting. This command prints the total number of failing results in one namespace:

<!-- astrona:playground:renew -->

```sh
kubectl get polr -n platform-ns -o json | jq '[.items[].summary.fail] | add'
```

The expression reads the `fail` counter from each report and adds the numbers. Using `summary` is faster than walking every entry in `results`, because Kyverno already computed the count.

## Turn the count into a gate

A shell script can compare the count with zero and set its exit code. A continuous integration job treats a non-zero exit code as a failure.

```sh
fails=$(kubectl get polr -n platform-ns -o json | jq '[.items[].summary.fail] | add // 0')
if [ "$fails" -gt 0 ]; then
  echo "platform-ns has $fails failing results"
  exit 1
fi
```

The `// 0` part is a jq default. When the namespace has no reports at all, `add` returns `null`, and the default turns it into `0`.

Remember what this gate cannot see. Advisory policies produce `warn`, not `fail`, so they never trip it. If you want advisory findings to block as well, add the `warn` counter to the sum on purpose, and document that decision.

## Wait for scans before you check

A freshly applied policy does not produce reports for existing resources until the next background scan. A gate that runs immediately after applying a policy can pass because the reports do not exist yet. Either wait for the scan interval, or evaluate the resources before they are deployed, which is what the CLI does.

## Create a report with the Kyverno CLI

The Kyverno CLI evaluates policies against resource files and does not need a cluster. Its `apply` command accepts a `--policy-report` flag that prints the outcome as a `PolicyReport`:

```sh
kyverno apply policy.yaml --resource pod.yaml --policy-report
```

The output uses the same report format you read in a cluster, so the same `jq` filters work on it. This makes the CLI a good fit for a pull request check, where the resource exists only as a manifest.

The CLI result describes one evaluation of the files you passed. It is not stored anywhere and it does not change the reports in any cluster.

> [!TIP]
> **Try it**
>
> Run the jq count against `platform-ns` and note the number. Then change the jq expression to add `summary.warn` as well, and compare the two totals. The difference is the number of advisory findings the first gate ignores.

You can now read reports by hand, by label, by filter and from a script, and you know that the CLI produces the same report format before a resource reaches the cluster.

## Common pitfalls

> [!WARNING]
> - Gating only on `summary.fail` while the important policies are scored as advisory. Check what your policies set with `policies.kyverno.io/scored`.
> - Running the gate before the reports exist. No report means a count of zero, which looks like success.
> - Treating a CLI report as the live state of the cluster. It describes only the files you evaluated.
