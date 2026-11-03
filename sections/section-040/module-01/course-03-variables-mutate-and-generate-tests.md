# Variables, Mutate and Generate Tests

Many policies read data that does not exist in a resource file: the user who made the request, the operation, or values from a ConfigMap. Mutate rules produce a new resource, and generate rules create one. This part shows how to feed variables to the CLI and how to test mutate and generate rules.

## A values file

A values file supplies variables to a policy. It is a YAML document of kind `Values`.

```yaml
apiVersion: cli.kyverno.io/v1alpha1
kind: Values
policies:
  - name: restrict-namespace
    rules:
      - name: check-ns
        values:
          allowedNamespace: team-a
    resources:
      - name: web
        values:
          request.operation: UPDATE
```

Rule-level `values` apply to every resource tested with the rule. Resource-level `values` apply to one named resource. Use the file with `kyverno apply policy.yaml --resource r.yaml --values-file values.yaml`, or set `values: values.yaml` in the Test object.

For a global value, a `globalValues` map in the same file applies to all rules.

## User information

Rules that match on `roles`, `clusterRoles` or `subjects` need request user data. A Test object can point to a `userinfo` file, for example `userinfo: user-info.yaml`. The file holds `roles`, `clusterRoles` and a `userInfo` block with `username` and `groups`.

## Testing a mutate rule

For a mutate rule, add `patchedResource` to the expectation. It names a file containing the resource as it should look after mutation.

```yaml
results:
  - policy: add-labels
    rule: add-team-label
    kind: Pod
    resources:
      - web
    patchedResource: patched-pod.yaml
    result: pass
```

The CLI mutates the input and compares the output with the file. A difference makes the test fail.

## Testing a generate rule

For a generate rule, add `generatedResource` with a file that holds the resource that should be created.

```yaml
results:
  - policy: add-networkpolicy
    rule: default-deny
    kind: Namespace
    resources:
      - team-a
    generatedResource: generated-networkpolicy.yaml
    result: pass
```

## Context entries

A rule with a `context` entry that reads a ConfigMap needs data. Put a ConfigMap in the resources list, or pass the data through the values file. API calls are not possible without a cluster, so rules that rely on them are better tested with `--cluster` or in a lab.

> [!TIP]
> **Try it - test a mutate rule**
>
> Write a mutate policy that adds a label to Pods. Create a Pod file and the expected patched Pod file. Add a `patchedResource` expectation and run `kyverno test .`. Remove the label from the patched file and confirm the test fails.

## Common pitfalls

- Expecting `result: pass` to mean the resource was valid. For a mutate rule it means the rule applied.
- A `patchedResource` that differs only in field order. The comparison is on the object, so order does not matter, but a missing default field does.
- Leaving `request.operation` unset for a rule that preconditions on it. The rule is skipped and the test sees `skip`.

With values, mutation and generation covered, one step remains: run all of this automatically, every time the policy changes.
