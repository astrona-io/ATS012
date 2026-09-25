# Part 2 — Tuning and Troubleshooting Reports

> Prerequisite: [Part 1 — The Reports Pipeline](./course-01-the-reports-pipeline.md). Next: [Section 020 — PolicyExceptions](../../section-020/README.md).

Every knob here lives on a controller Deployment's container args or in the `kyverno` ConfigMap. There is no `spec` field on a policy that changes how reporting works — reporting is an installation-level concern, which is exactly why it tends to be owned by the platform team rather than the policy authors.

## Making background scans happen on your schedule

`--backgroundScanInterval` on `kyverno-reports-controller` sets how often the periodic re-scan of already-existing resources runs. Default `1h`; it accepts minute durations.

```sh
kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
]'
kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s
```

Appending to `args` with `"path": ".../args/-"` adds a new element at the end of the list. Kyverno's flag parsing takes the last occurrence of a repeated flag, so this reliably overrides the value baked into the manifest without you having to know its index.

**The cost is real.** Each scan re-evaluates every matching resource in the cluster against every active policy and writes the results. At `1m` on a cluster with tens of thousands of resources, the reports controller becomes one of the busiest clients of your API server, and report objects churn continuously. Lower it for labs, demos, and incident investigations; leave production somewhere between `10m` and the default `1h` unless you have measured the load and decided you can afford it.

`--backgroundScanWorkers` (default `2`) is the other half of the same trade: more worker threads process a scan faster, at the cost of more CPU and more concurrent API calls. Raise it when a single scan cycle takes longer than the interval between cycles — visible as a reports controller that is permanently busy and reports that are permanently stale.

## Turning reporting off for a rule type

`--enableReporting` takes a comma-separated list of rule types and defaults to `validate,mutate,mutateExisting,imageVerify,generate`. Removing a type stops report entries being produced for it:

```sh
kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enableReporting=validate"}
]'
```

That configuration reports validate findings and nothing else. It is a blunt instrument, and the usual reason to reach for it is volume: `mutate` and `generate` rules that fire on every single Pod create can produce a `pass` entry per resource per rule, which is a lot of writes for information nobody reads. The flag has to be set on **both** the admission controller and the reports controller to take full effect — each one produces report data independently.

> [!WARNING]
> **Common pitfall**
>
> Setting `--enableReporting` on one controller and assuming the whole cluster is covered. If you disable `validate` reporting only on the reports controller, admission-path findings from the admission controller keep flowing in, and you get the confusing result that new violations are reported while old ones are not.

## resourceFilters, and the flag that makes it not apply

The `kyverno` ConfigMap in the `kyverno` namespace carries a `resourceFilters` entry — a list of `[kind,namespace,name]` triples, wildcards allowed, naming resources the Kyverno engine should not evaluate at all:

```sh
kubectl get configmap kyverno -n kyverno -o jsonpath='{.data.resourceFilters}' | head -20
```

A stock install already excludes `[*/*,kube-system,*]`, `[Event,*,*]`, `[Node,*,*]`, `[ReplicaSet,*,*]`, and every one of Kyverno's own objects — which is why you do not see a wall of findings about the control plane. Adding your own entry is how you take a noisy namespace out of policy processing entirely:

```sh
kubectl -n kyverno patch configmap kyverno --type=merge -p \
  '{"data":{"resourceFilters":"[*/*,kube-system,*]\n[Event,*,*]\n[*/*,noisy-ns,*]"}}'
```

Now the subtlety that catches almost everybody. The reports controller ships with:

```text
--skipResourceFilters=true
```

The flag reads as "skip *applying* the resource filters", and `true` is the default. In other words, **background scans deliberately ignore `resourceFilters`**. A namespace you filtered out of admission processing will still be scanned and still produce `PolicyReport` entries. If you want the filter to apply to reporting as well, you have to say so:

```sh
kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--skipResourceFilters=false"}
]'
kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s
```

The default is deliberate: `resourceFilters` exists mainly to keep the admission webhook off the hot path for resources where policy would be pointless or dangerous, and the designers did not want that performance decision to silently blind your compliance reporting. Whether that is the behaviour *you* want is a policy question for your organisation.

> As an analogy: `resourceFilters` is a "do not disturb" sign the engine respects at the door. `--skipResourceFilters=true` means the night auditor walking the corridors with a clipboard ignores the sign and writes down what they see anyway. Useful — unless you genuinely wanted that room off the record, in which case you have to tell the auditor too.

## Diagnosing a missing report, in order

When a finding you expect is not in a report, work down this list rather than guessing. Each step is cheap and eliminates a whole class of causes.

1. **Is the policy live and did it survive admission?**
   ```sh
   kubectl get clusterpolicy <name> -o wide
   ```
   A policy that failed Kyverno's own schema webhook never became an object at all.

2. **Would this policy ever report on an existing resource?** `background` is a **policy-level** field (`spec.background`, default `true`), not a per-rule one. A policy with `spec.background: false` is never evaluated by a background scan — only at admission. A pre-existing resource plus `spec.background: false` equals no report for that policy, forever, by design. It is the correct setting for a policy whose rules reference admission-only context such as `request.userInfo`.

3. **Are you looking in the right kind and namespace?** Namespaced resource means `polr` in that resource's namespace; cluster-scoped resource means `cpolr`. `kubectl get polr -A -o wide` sweeps everything.

4. **Have you actually waited for a scan?** Check the interval, and remember the default is an hour:
   ```sh
   kubectl get deployment kyverno-reports-controller -n kyverno \
     -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep backgroundScanInterval
   ```

5. **Is reporting enabled for this rule type?** Check `--enableReporting` on both the admission controller and the reports controller.

6. **Is the pipeline healthy?** Look for ephemeral reports piling up unaggregated, then read the controller's logs:
   ```sh
   kubectl get ephemeralreports -A
   kubectl logs -n kyverno deployment/kyverno-reports-controller --tail=50
   ```

> [!TIP]
> **Try it — go from "nothing in the report" to "there it is" in two minutes**
>
> ```sh
> kubectl get polr -n platform-ns -o wide          # likely empty for the pre-existing Deployment
> kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
>   {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
> ]'
> kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s
> sleep 90
> kubectl get polr -n platform-ns -o wide          # the pre-existing Deployment now appears
> ```
>
> Nothing about the policy changed. The only thing you altered was how often the auditor walks the corridor.

## Self-check

1. Which controller produces report data for a Pod being created right now, and which one produces it for a Pod created last month?
2. Your reports are an hour stale and the reports controller is pegged at 100% CPU. Which flag do you reach for first, and why not `--backgroundScanInterval`?
3. You added `[*/*,noisy-ns,*]` to `resourceFilters` and `noisy-ns` is still producing `PolicyReport` entries. What is happening, and what do you change?
4. Why should you not write a dashboard that reads `ephemeralreports`?

## Reference

- [Kyverno docs — Container flags](https://kyverno.io/docs/installation/customization/) — every flag in this chapter, with defaults and which controller accepts it.
- `kubectl get configmap kyverno -n kyverno -o yaml` — `resourceFilters`, `excludeGroups`, `webhooks`, and the rest of the installation-level configuration.
