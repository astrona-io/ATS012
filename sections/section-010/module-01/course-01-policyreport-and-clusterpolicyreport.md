# Part 1 — PolicyReport and ClusterPolicyReport

> Prerequisite: [Module landing page](./course.md). Next: [Part 2 — Reading Results: the Five Result Types](./course-02-reading-results-and-result-types.md).

## Two objects, one rule for choosing between them

Kyverno does not invent its own reporting format. It writes into two Custom Resources defined by the Kubernetes Policy Working Group, which means the same objects are produced by other policy engines too — a dashboard built for one speaks to the other.

| | `PolicyReport` | `ClusterPolicyReport` |
| :--- | :--- | :--- |
| API group/version | `wgpolicyk8s.io/v1alpha2` | `wgpolicyk8s.io/v1alpha2` |
| Short name | `polr` | `cpolr` |
| Scope | Namespaced | Cluster-scoped |
| Describes | A namespaced resource (Pod, Deployment, ConfigMap…) | A cluster-scoped resource (Namespace, ClusterRole, PersistentVolume…) |

The rule for which one a finding lands in is simple and has nothing to do with the policy: **it follows the resource being reported on, not the policy doing the reporting.** A `ClusterPolicy` — cluster-scoped itself — that evaluates Pods writes into namespaced `PolicyReport` objects in each Pod's own namespace, because a Pod is a namespaced resource. The same `ClusterPolicy` evaluating `Namespace` objects writes into `ClusterPolicyReport`, because a Namespace is cluster-scoped.

> As an analogy: think of the two report kinds as two filing cabinets in a building — one cabinet per floor for the things that live on that floor, and one cabinet in the lobby for things that belong to the building itself. The inspector (the policy) is the same person walking the whole building; which cabinet the paperwork goes into depends on what was inspected, not on who inspected it. The analogy breaks down in one place: unlike paper files, these are live objects Kyverno rewrites continuously as the cluster changes.

## Why your reports have UUID names

Run `kubectl get polr -A` on a modern Kyverno cluster and you will see something like this:

```text
NAMESPACE     NAME                                   KIND         NAME           PASS   FAIL   WARN   ERROR   SKIP   AGE
platform-ns   487df031-11d8-4ab4-b089-dfc0db1e533e   Deployment   legacy-api     0      1      0      0       0      3m
platform-ns   9b1c2d44-6f3a-4c11-9d67-2a8ef0b41c55   Pod          compliant-pod  1      0      0      0       0      3m
```

Those names are not random and they are not policy names. Since Kyverno 1.10 the reports system is **per-resource**: one report object per reported resource, named after that resource's `metadata.uid`. Earlier versions aggregated everything in a namespace into a single `polr-ns-<namespace>` object, which meant a namespace with ten thousand Pods produced one enormous object that every controller had to re-read on every change.

The practical consequences of the per-resource model are worth internalising:

- **You never look a report up by name.** You look it up by the resource it describes — and the fastest route is the printer columns, which already show `KIND` and `NAME`:

  ```sh
  kubectl get polr -n platform-ns -o wide
  ```

- **Deleting the resource deletes its report.** Each report carries an `ownerReferences` entry pointing at the resource it describes, so Kubernetes garbage-collects the report when the Pod or Deployment goes away. You do not clean reports up by hand.
- **A report covers one resource and every policy that looked at it.** The `results[]` array inside holds one entry per *rule* that evaluated, so a single Pod checked by four rules across three policies produces one report with four result entries — not four reports.

## What is inside a report

```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: 487df031-11d8-4ab4-b089-dfc0db1e533e
  namespace: platform-ns
  ownerReferences:
    - apiVersion: apps/v1
      kind: Deployment
      name: legacy-api
      uid: 487df031-11d8-4ab4-b089-dfc0db1e533e
scope:
  apiVersion: apps/v1
  kind: Deployment
  name: legacy-api
  namespace: platform-ns
results:
  - policy: require-resource-limits
    rule: check-limits
    result: fail
    severity: medium
    message: "Every container must set resources.limits.cpu and resources.limits.memory."
    scored: true
    source: kyverno
    category: Best Practices
    timestamp:
      seconds: 1726300000
      nanos: 0
    properties:
      process: background scan
summary:
  pass: 0
  fail: 1
  warn: 0
  error: 0
  skip: 0
```

The three fields you will use constantly:

- **`scope`** — the resource this whole report is about. This is the field a dashboard joins on, and the one that answers "what is this UUID?"
- **`results[]`** — one entry per rule evaluation. Each carries the `policy` name, the `rule` name, the `result` value, the human-readable `message` that the rule's `validate.message` produced, and a `properties.process` field telling you whether this entry came from an `admission review` or a `background scan`.
- **`summary`** — the five counters, pre-aggregated. This is what the printer columns display, and it is what you check first when you just want to know "is anything failing in here?"

> [!TIP]
> **Try it — find the report for one specific Deployment**
>
> ```sh
> kubectl get polr -n platform-ns -o wide
> uid=$(kubectl get deployment legacy-api -n platform-ns -o jsonpath='{.metadata.uid}')
> kubectl get polr "$uid" -n platform-ns -o yaml
> ```
>
> The report's name is exactly the Deployment's UID. Confirm that `scope.kind` is `Deployment`, that `scope.name` is `legacy-api`, and that `summary.fail` matches the `FAIL` column you saw in the first command.

> [!WARNING]
> **Common pitfall**
>
> Running `kubectl get policyreport` with no `-n` or `-A` and concluding that reporting is broken. `PolicyReport` is namespaced, so a bare `kubectl get polr` only searches your current namespace — which is usually `default`, where nothing interesting is running. Use `-A` to sweep the whole cluster, and remember that findings about cluster-scoped resources are not in `polr` at all; they are in `cpolr`.

## Reference

- `kubectl get polr -A -o wide` / `kubectl get cpolr -o wide` — the two commands that start every report investigation.
- `kubectl explain policyreport.results` — the full result schema, straight from the CRD installed on your cluster.
- [Kyverno docs — Policy Reports](https://kyverno.io/docs/policy-reports/) — the upstream reference for the report model.
