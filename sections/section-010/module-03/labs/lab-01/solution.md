# Solution

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-03/labs/lab-01
```

## Step 1: Apply the high-severity policy

The severity and category are annotations on the policy. Kyverno copies them into every result the policy produces. Create `require-resource-limits.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
  annotations:
    policies.kyverno.io/severity: high
    policies.kyverno.io/category: Best Practices
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-limits
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - team-red
              - team-blue
      validate:
        message: "Every container must set resources.limits.cpu and resources.limits.memory."
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    cpu: "?*"
                    memory: "?*"
```

```sh
kubectl apply -f require-resource-limits.yaml
```

## Step 2: Apply the medium-severity policy

Create `require-team-label.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label
  annotations:
    policies.kyverno.io/severity: medium
    policies.kyverno.io/category: Governance
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-team
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - team-red
              - team-blue
      validate:
        message: "Every Pod must carry a 'team' label."
        pattern:
          metadata:
            labels:
              team: "?*"
```

```sh
kubectl apply -f require-team-label.yaml
```

Grade the first check:

```sh
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-03/labs/lab-01 --keep
```

The check `policies-carry-severity-and-category` should pass. The other two checks fail until you finish the later steps.

## Step 3: Read severity and category on a result

The Pods already existed, so the findings come from the background scan, which runs every minute. List the reports and wait until `red-bad` shows a failure:

```sh
kubectl get polr -n team-red -o wide
```

Then read the entries of that report. Reports are named after the Pod's UID, so look the report up by the `NAME` column or by `scope.name`:

```sh
kubectl get polr -n team-red -o jsonpath='{range .items[*]}{.scope.name}{"\t"}{.summary.fail}{"\n"}{end}'
kubectl get polr -n team-red -o yaml
```

In the YAML, each entry of `results[]` carries `policy`, `rule`, `result`, `severity` and `category`. The values come from the annotations you wrote in steps 1 and 2.

## Step 4: Delete red-bad and watch its report go

```sh
kubectl delete pod red-bad -n team-red
kubectl get polr -n team-red -o jsonpath='{.items[*].scope.name}'
```

The report is owned by the Pod, so Kubernetes garbage-collects it. Re-run the second command until `red-bad` is no longer listed. Do not delete the report yourself.

Grade it:

```sh
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-03/labs/lab-01 --keep
```

The check `red-bad-removed-with-its-report` should pass.

## Step 5: Count failures per severity

A jsonpath filter inside `range` selects the results with one severity, and `grep -c` counts the `fail` lines:

```sh
kubectl get polr -A -o jsonpath='{range .items[*].results[?(@.severity=="high")]}{.result}{"\n"}{end}' | grep -c '^fail$'
kubectl get polr -A -o jsonpath='{range .items[*].results[?(@.severity=="medium")]}{.result}{"\n"}{end}' | grep -c '^fail$'
```

Only `blue-bad` is left, and it breaks one rule of each policy, so you should get `1` and `1`. Count them yourself from the live reports rather than copying these numbers: the grader recomputes them.

## Step 6: Record the counts

Replace the numbers with what you counted:

```sh
kubectl create configmap triage-summary -n platform-ns --from-literal=high-fail=1 --from-literal=medium-fail=1
```

Grade it:

```sh
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-010/module-03/labs/lab-01
```

All three checks should pass.

## Common mistakes

- Putting the severity on the rule instead of the policy. The annotation belongs in the policy's `metadata.annotations`.
- Counting with `kubectl get polr -n team-red` only. The `-A` flag covers every namespace.
- Counting before the deletion has settled. A stale count of `2` means `red-bad`'s report was still there.
