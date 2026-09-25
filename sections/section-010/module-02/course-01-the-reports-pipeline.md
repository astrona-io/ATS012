# Part 1 — The Reports Pipeline

> Prerequisite: [Module landing page](./course.md). Next: [Part 2 — Tuning and Troubleshooting Reports](./course-02-tuning-and-troubleshooting-reports.md).

## Four controllers, and only two of them touch reports

A default Kyverno v1.13.2 install runs four Deployments in the `kyverno` namespace:

```sh
kubectl get deployment -n kyverno
```

```text
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
kyverno-admission-controller    1/1     1            1           4m
kyverno-background-controller   1/1     1            1           4m
kyverno-cleanup-controller      1/1     1            1           4m
kyverno-reports-controller      1/1     1            1           4m
```

For reporting, two of them matter:

- **`kyverno-admission-controller`** sits in the admission path. When an `Audit`-mode validate rule finds a violation on an incoming resource, this controller admits the resource and records the finding — immediately, as part of handling the request.
- **`kyverno-reports-controller`** owns everything else: the periodic background scan of resources that already exist, and the aggregation step that turns raw findings into the `PolicyReport` objects you read.

The `kyverno-background-controller` is *not* the reports controller, despite the name. It owns `generate` and `mutateExisting` rules — making new resources and patching old ones. Background *scanning* for reports belongs to the reports controller. This naming collision trips people up constantly; if you are debugging a missing report, the background controller's logs are almost never where the answer is.

## The intermediate objects: EphemeralReport

Neither controller writes straight into a `PolicyReport`. Both write into an intermediate CRD first:

```sh
kubectl get crd | grep reports.kyverno.io
```

```text
clusterephemeralreports.reports.kyverno.io
ephemeralreports.reports.kyverno.io
```

An `EphemeralReport` is a single, short-lived finding about a single resource, written by whichever controller produced it. The reports controller then watches these, merges every finding about the same resource together, writes the result into the `PolicyReport`, and deletes the ephemeral object. That merge step is what `--aggregateReports=true` (the default) controls.

Why the indirection? Because two controllers write findings and only one object may exist per resource. Without a staging area, the admission controller and the reports controller would fight over the same `PolicyReport` on every update, and a busy cluster would spend its API server budget on write conflicts. The `EphemeralReport` layer lets both producers append freely and lets exactly one consumer own the final object.

> [!WARNING]
> **Common pitfall**
>
> Building scripts, dashboards, or alerts against `ephemeralreports`. They are internal plumbing: they appear and disappear within seconds, their schema is not the stable Policy WG schema, and Kyverno is free to change how they work between minor versions. Read `polr` and `cpolr`; look at `ephemeralreports` only when diagnosing the pipeline itself.

## Two paths, two very different latencies

This is the single most useful thing in this module.

**The admission path is immediate.** A Pod created right now, violating an `Audit` rule right now, produces report data as part of that admission request. Allowing a few seconds for aggregation, the finding is in the `PolicyReport` almost at once.

**The background path is not.** A resource that already existed when you applied the policy is invisible to admission control — nothing is happening to it, so there is no admission request to evaluate. It only gets looked at when the reports controller runs a background scan, and that happens **every `--backgroundScanInterval`, which defaults to `1h`**.

```sh
kubectl get deployment kyverno-reports-controller -n kyverno \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -i background
```

```text
"--backgroundScan=true"
"--backgroundScanWorkers=2"
"--backgroundScanInterval=1h"
```

So the honest answer to "I applied a policy and the old Deployment is not in the report" is very often: *it is not broken, you are early.* Kyverno does kick off a scan when a policy is created or changed, so in practice you frequently get results sooner than the full hour — but nothing guarantees a fast result, and in a lab or a demo waiting an hour is not an option. Part 2 covers turning that dial down.

> [!TIP]
> **Try it — watch both paths on one cluster**
>
> With an `Audit` policy applied to a namespace that already contains a violating Deployment:
>
> ```sh
> # background path: the pre-existing workload
> kubectl get polr -n platform-ns -o wide
>
> # admission path: create a fresh violator and re-check within seconds
> kubectl -n platform-ns run fresh-violator --image=nginx:alpine
> sleep 10
> kubectl get polr -n platform-ns -o wide
> ```
>
> The `fresh-violator` Pod's report shows up quickly — it went through admission. The pre-existing Deployment's report may still be absent until a background scan runs. Same policy, same namespace, same rule; two different clocks.

## What each controller needs in order to report at all

Both the admission controller and the reports controller carry an `--enableReporting` flag, defaulting to `validate,mutate,mutateExisting,imageVerify,generate` — the rule types that are allowed to produce report data. Both also carry `--enablePolicyException=false` by default, which matters in Section 020: an exception that the admission controller honours will not show up as `skip` in your reports unless the reports controller has been told about exceptions too.

```sh
kubectl get deployment kyverno-reports-controller -n kyverno \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -E 'Report|reporting|Exception'
```

## Reference

- `kubectl get deployment -n kyverno` — the four controllers and their health.
- `kubectl logs -n kyverno deployment/kyverno-reports-controller` — where background-scan and aggregation problems surface.
- [Kyverno docs — Container flags](https://kyverno.io/docs/installation/customization/) — the full flag table, annotated by which controller accepts each flag.
