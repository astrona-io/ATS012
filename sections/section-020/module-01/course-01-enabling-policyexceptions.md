# Part 1 — Enabling PolicyExceptions

> Prerequisite: [Module landing page](./course.md). Next: [Part 2 — The Anatomy of a PolicyException](./course-02-anatomy-of-a-policyexception.md).

## The feature is off by default, and that is a security decision

Create a `PolicyException` on a stock Kyverno v1.13.2 install and nothing happens. The object is accepted — the CRD `policyexceptions.kyverno.io` is installed, the API server stores it happily, `kubectl get policyexception` shows it sitting there — and the policy it claims to except keeps enforcing exactly as before.

That silence is the single most confusing thing about this feature, so understand why it is there. A `PolicyException` is, by definition, a hole in your enforcement. If exceptions were honoured by default, then *anyone who can create an object in any namespace* could switch off any rule for any resource they control. That turns a cluster-wide security control into an opt-out, and it does so through an object most cluster admins have never heard of.

Kyverno's answer is to make the cluster operator opt in twice: once to the feature, and once to a specific namespace where exceptions are allowed to live.

```sh
kubectl get deployment kyverno-admission-controller -n kyverno \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -i exception
```
```text
"--enablePolicyException=false"
```

## The two flags

**`--enablePolicyException`** (default `false`) turns the feature on. Nothing else matters until this is `true`.

**`--exceptionNamespace`** names the namespace Kyverno will honour exceptions from. An exception object created anywhere else is ignored — silently, exactly as if the feature were off. If you leave it unset while enabling the feature, exceptions are honoured from *every* namespace, which is precisely the blast radius the design is trying to avoid.

> As an analogy: `--enablePolicyException=true` unlocks the door marked "exemptions". `--exceptionNamespace=platform-ns` says only paperwork filed from one specific office counts. Without the second flag you have unlocked the door and told the whole building that any note slipped under it is binding. The analogy understates it slightly — unlike paperwork, a bad exception takes effect the instant it is created, with no one in the loop.

Putting both on the admission controller:

```sh
kubectl -n kyverno patch deployment kyverno-admission-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enablePolicyException=true"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--exceptionNamespace=platform-ns"}
]'
kubectl -n kyverno rollout status deployment/kyverno-admission-controller --timeout=180s
```

## Which controllers need the flags

This is where most half-working setups come from. Three of Kyverno's four controllers carry `--enablePolicyException`, and they use it for different things:

| Controller | What the flag changes there |
| :--- | :--- |
| `kyverno-admission-controller` | Whether an exception is honoured **at admission time** — i.e. whether the blocked Pod is actually admitted. |
| `kyverno-reports-controller` | Whether a background scan honours the exception — i.e. whether the report says `skip` instead of `fail`. |
| `kyverno-background-controller` | Whether `generate` and `mutateExisting` processing honours the exception. |

Enable it only on the admission controller and you get a cluster where the workload is admitted but your compliance report still shows it failing — the enforcement and the record disagree, and the report is the thing your auditor reads. Enable it only on the reports controller and you get the reverse: a clean-looking report for a workload that is still being blocked.

For a validate-rule exception you want it on both the admission controller and the reports controller:

```sh
for d in kyverno-admission-controller kyverno-reports-controller; do
  kubectl -n kyverno patch deployment "$d" --type=json -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enablePolicyException=true"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--exceptionNamespace=platform-ns"}
  ]'
  kubectl -n kyverno rollout status "deployment/$d" --timeout=180s
done
```

Appending to `args` with `path: ".../args/-"` adds each flag at the end of the existing list. Kyverno honours the last occurrence of a repeated flag, so this overrides the shipped `false` without you needing to know its index.

> [!WARNING]
> **Common pitfall**
>
> Creating the exception, seeing the workload still blocked, and concluding the exception's `match` block is wrong. Check the flags first — it is the more common cause by a wide margin, and it produces no error message anywhere. `kubectl describe policyexception` will not tell you the feature is off, because from the API server's point of view nothing is wrong.

> [!TIP]
> **Try it — confirm the flags landed**
>
> ```sh
> for d in kyverno-admission-controller kyverno-reports-controller; do
>   echo "== $d"
>   kubectl get deployment "$d" -n kyverno \
>     -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -i exception
> done
> ```
>
> Expect to see both the original `"--enablePolicyException=false"` and your appended `"--enablePolicyException=true"` on each. Both being present is normal and correct — the later value wins.

## Reference

- `kubectl get crd policyexceptions.kyverno.io -o jsonpath='{.spec.versions[*].name}'` — the served API versions on your cluster (`v2` on Kyverno 1.13).
- [Kyverno docs — Policy Exceptions](https://kyverno.io/docs/exceptions/) — upstream reference, including the newer CEL-based exception type introduced for the `policies.kyverno.io` policy family.
