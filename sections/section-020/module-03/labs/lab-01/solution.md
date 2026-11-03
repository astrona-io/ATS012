# Solution

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-03/labs/lab-01
```

## Step 1: Let the cleanup controller delete exceptions

The `cleanup.kyverno.io/ttl` label is handled by the cleanup controller, and the controller can only delete what RBAC lets it delete. Its ClusterRole is aggregated, so you add rights with a ClusterRole that carries the aggregation label:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cleanup-policyexceptions
  labels:
    rbac.kyverno.io/aggregate-to-cleanup-controller: "true"
rules:
  - apiGroups: ["kyverno.io"]
    resources: ["policyexceptions"]
    verbs: ["get", "list", "watch", "delete"]
```

```sh
kubectl apply -f cleanup-policyexceptions.yaml
kubectl auth can-i delete policyexceptions.kyverno.io -n platform-ns --as=system:serviceaccount:kyverno:kyverno-cleanup-controller
```

The `can-i` answer should become `yes` within a few seconds, after the aggregation controller has merged the rules. Grade it:

```sh
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-03/labs/lab-01 --keep
```

The check `cleanup-controller-may-delete-exceptions` should pass.

## Step 2: Require a ttl on every exception

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-exception-ttl
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-ttl
      match:
        any:
        - resources:
            kinds:
              - PolicyException
      validate:
        message: "A PolicyException must carry the label cleanup.kyverno.io/ttl so that it expires."
        pattern:
          metadata:
            labels:
              cleanup.kyverno.io/ttl: "?*"
```

```sh
kubectl apply -f require-exception-ttl.yaml
```

`background: false` is deliberate: the rule's job is to stop an exception without an end date from being created.

## Step 3: Prove the policy blocks

```sh
kubectl apply -f - <<'YAML'
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: no-ttl
  namespace: platform-ns
spec:
  exceptions:
    - policyName: batch-require-limits
      ruleNames:
        - check-limits
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - batch-ns
YAML
```

The request should be rejected with a message from `require-exception-ttl`. Confirm that nothing was created:

```sh
kubectl get policyexception -n platform-ns
```

## Step 4: Create the time-boxed exception

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: allow-batch-timeboxed
  namespace: platform-ns
  labels:
    cleanup.kyverno.io/ttl: 8h
  annotations:
    exception.company.io/owner: "platform-team"
spec:
  exceptions:
    - policyName: batch-require-limits
      ruleNames:
        - check-limits
        - autogen-check-limits
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - batch-ns
          names:
            - "grace-*"
```

```sh
kubectl apply -f allow-batch-timeboxed.yaml
kubectl get policyexception -n platform-ns -L cleanup.kyverno.io/ttl
```

The ttl is counted from the creation of the object, so this exception is deleted about eight hours after it was created.

## Step 5: Show the exception works, and only where intended

```sh
kubectl run grace-pod -n batch-ns --image=nginx:alpine --restart=Never
kubectl run strict-pod -n batch-ns --image=nginx:alpine --restart=Never
```

`grace-pod` should be admitted, because its name begins with `grace-`. `strict-pod` should be rejected by `batch-require-limits`. Confirm that `strict-pod` does not exist:

```sh
kubectl get pods -n batch-ns
```

Grade it:

```sh
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-020/module-03/labs/lab-01
```

All three checks should pass.

## Common mistakes

- Using an annotation `exception.company.io/expires` and expecting Kyverno to act on it. Only the label `cleanup.kyverno.io/ttl` is handled, and only by the cleanup controller.
- Forgetting the ClusterRole. The label is accepted, nothing is deleted and the exception lives on.
- Naming only `check-limits` in `ruleNames`. A Pod created by a Deployment is judged through the autogen rule.
