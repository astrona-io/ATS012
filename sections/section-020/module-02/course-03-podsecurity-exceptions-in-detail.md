# Part 3 — Pod Security Exceptions in Detail

The Pod Security Standards (PSS) are three profiles: `privileged`, `baseline` and `restricted`. Kyverno enforces them with a `validate.podSecurity` rule. One PSS rule contains many controls, such as Host Namespaces or Capabilities. Waiving the whole rule to allow one control is too much. The `podSecurity` field of an exception waives a single control.

## The structure of a `podSecurity` entry

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: allow-host-network-monitoring
  namespace: platform-ns
spec:
  exceptions:
    - policyName: pss-baseline
      ruleNames:
        - baseline
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - monitoring
          names:
            - node-agent-*
  podSecurity:
    - controlName: Host Namespaces
```

The `controlName` is the name of a PSS control, written exactly as the Kyverno documentation lists it, for example `Host Namespaces`, `Privileged Containers`, `Capabilities`, `HostPath Volumes` or `Host Ports`.

## Controls that name images

Some controls report the container image that breaks them. For these, the entry can limit the waiver to specific images with `images`:

```yaml
  podSecurity:
    - controlName: Capabilities
      images:
        - registry.example.com/agent:*
```

Only containers using a matching image are waived. A second container in the same Pod with another image is still checked. This is the most precise form of waiver, so use it whenever the control supports it.

## `restrictedField` and `values`

For the controls that look at one field, `restrictedField` names the field and `values` lists the values that are allowed:

```yaml
  podSecurity:
    - controlName: Capabilities
      images:
        - registry.example.com/agent:*
      restrictedField: spec.containers[*].securityContext.capabilities.add
      values:
        - NET_ADMIN
```

This waives only the added capability `NET_ADMIN`. Adding `SYS_ADMIN` in the same container is still blocked. Without `restrictedField` and `values`, every value of the control passes for the matched images.

## The exception names the rule, not only the control

`ruleNames` still names the policy rule that contains the `podSecurity` check. The `podSecurity` list then narrows which part of that rule is waived. If you write `ruleNames` and no `podSecurity` list, the exception waives the full rule.

## Seeing the narrowing work

When the waiver covers only one control, the other controls of the same profile keep failing. The policy report then shows `fail` for the other controls and the message names the control that failed, not the one you waived.

> [!TIP]
> **Try it - waive one control and test a second**
>
> Create a PSS `baseline` policy in `Enforce` mode. Apply an exception for `Host Namespaces` for one named Pod. Create the Pod with `hostNetwork: true`: it is admitted. Create the same Pod with `privileged: true` added: it is blocked, and the message names the Privileged Containers control.

## Common pitfalls

- A `controlName` that is misspelled or in the wrong case. The exception is accepted but waives nothing.
- Waiving a control without `images`. Any image in the matched Pod then passes the control.
- Forgetting that the exception does not change the PSS profile or its version in the policy. It only waives what you list.
- Expecting `podSecurity` to work with a plain `validate.pattern` rule. It is for `validate.podSecurity` rules.

## Where this leaves you

You can write an exception that waives one control, one image and one value of a Pod Security Standards rule. The next part covers how to review all those exceptions as they accumulate.
