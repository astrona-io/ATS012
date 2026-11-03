# Part 4 — Enabling with Helm and Troubleshooting

In a real cluster Kyverno is installed with Helm, not by editing controller arguments by hand. A manual edit is lost on the next `helm upgrade`. This part shows the chart values that turn the feature on, and a fixed checklist to follow when an exception does not apply.

## Enabling the feature in the Helm chart

The Kyverno chart (version 3.x, which installs Kyverno v1.13) exposes the feature under `features.policyExceptions`:

```yaml
features:
  policyExceptions:
    enabled: true
    namespace: platform-ns
```

`enabled: true` sets `--enablePolicyException=true`. `namespace` sets `--exceptionNamespace`. Apply the values with `helm upgrade`, and the chart sets the arguments on every controller that needs them.

```sh
helm upgrade kyverno kyverno/kyverno -n kyverno --reuse-values \
  --set features.policyExceptions.enabled=true \
  --set features.policyExceptions.namespace=platform-ns
```

An empty `namespace` means exceptions are honoured in any namespace. That is the setting that lets any user who can create a `PolicyException` waive a policy, so set it.

## Verify the flags are in place

Read the arguments of the admission controller and the reports controller:

```sh
kubectl -n kyverno get deploy kyverno-admission-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}'
kubectl -n kyverno get deploy kyverno-reports-controller \
  -o jsonpath='{.spec.template.spec.containers[0].args}'
```

Both lists must contain `--enablePolicyException=true` and the same `--exceptionNamespace` value.

## The troubleshooting checklist

When the policy still blocks a workload that you expected to be exempt, check in this order:

1. The flags are present on both controllers, as shown above.
2. The exception lives in the namespace named by `--exceptionNamespace`: `kubectl get policyexception -A`.
3. `policyName` equals the policy name exactly. For a namespaced `Policy`, the name is written as `<namespace>/<policy>`.
4. Every name in `ruleNames` exists in the policy, including the `autogen-` rule for workload controllers.
5. The `match` block selects the Pod that is being created, not only its parent.
6. The policy rule is a rule type that exceptions support, and the resource is in the rule's own scope.

If all six hold, read the admission controller log for the request:

```sh
kubectl -n kyverno logs deploy/kyverno-admission-controller --tail=200
```

Then re-create the Pod and compare the result in its PolicyReport: a `skip` result with `properties.exceptions` set confirms the exception applied.

> [!TIP]
> **Try it - break each item of the checklist**
>
> In the playground, take a working exception and change one thing at a time: the namespace, the policy name, one rule name, the `match` namespace. After each change, recreate the Pod and record whether it is blocked. You learn which mistake produces which symptom.

## Common pitfalls

- Setting the flags with `kubectl edit` and losing them on the next chart upgrade.
- Enabling the feature on the admission controller only. Admission works, and reports keep showing `fail`.
- Testing with a Pod that already exists. Admission runs only on create and update, so check a new Pod, or wait for the next background scan.
- Reading only the exception object and not the report. The report is the proof that the exception applied.

## Where this leaves you

You can enable exceptions in a way that survives upgrades, confirm the configuration on the controllers, and diagnose a non-working exception in a fixed order. The next module narrows exceptions further and puts governance around them.
