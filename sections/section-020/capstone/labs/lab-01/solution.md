# Solution Walkthrough

---

## Step 1: Enable and Scope the Feature

```sh
for d in kyverno-admission-controller kyverno-reports-controller; do
  kubectl -n kyverno patch deployment "$d" --type=json -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enablePolicyException=true"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--exceptionNamespace=platform-ns"}
  ]'
done

kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
]'

for d in kyverno-admission-controller kyverno-reports-controller; do
  kubectl -n kyverno rollout status "deployment/$d" --timeout=180s
done
```

`--exceptionNamespace` is the part that makes Step 7 fail the way it should. Without it, every namespace in the cluster becomes an exemption-granting authority.

---

## Step 2: The Enforcement Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prod-require-limits
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-limits
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - prod-ns
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

---

## Step 3: The Hygiene Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-exception-metadata
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-owner-and-expiry
      match:
        any:
        - resources:
            kinds:
              - PolicyException
      validate:
        message: "A PolicyException must carry 'exception.company.io/owner' and 'exception.company.io/expires' annotations."
        pattern:
          metadata:
            annotations:
              exception.company.io/owner: "?*"
              exception.company.io/expires: "?*"
```
```sh
kubectl apply -f prod-require-limits.yaml
kubectl apply -f require-exception-metadata.yaml
```

Note that this hygiene rule matches every `PolicyException` in the cluster, including the one in `rogue-ns` you create later. It enforces *how* exceptions are written; `--exceptionNamespace` enforces *where* they count. Two different controls, and you want both.

---

## Step 4: The Real Exception

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: allow-payments-api
  namespace: platform-ns
  annotations:
    exception.company.io/owner: "payments-team"
    exception.company.io/expires: "2026-12-31"
spec:
  exceptions:
    - policyName: prod-require-limits
      ruleNames:
        - check-limits
        - autogen-check-limits
  match:
    any:
      - resources:
          kinds:
            - Pod
            - Deployment
          namespaces:
            - prod-ns
          names:
            - "payments-api*"
```
```sh
kubectl apply -f allow-payments-api.yaml
```

---

## Step 5: Re-roll the Exempted Workload

```sh
kubectl -n prod-ns patch deployment payments-api -p \
  '{"spec":{"template":{"metadata":{"annotations":{"force-reroll":"1"}}}}}'
kubectl -n prod-ns rollout status deployment/payments-api --timeout=180s
kubectl get pods -n prod-ns
```

---

## Step 6: The Rogue Exception

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: rogue-exception
  namespace: rogue-ns
  annotations:
    exception.company.io/owner: "someone-else"
    exception.company.io/expires: "2026-12-31"
spec:
  exceptions:
    - policyName: prod-require-limits
      ruleNames:
        - check-limits
        - autogen-check-limits
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - prod-ns
          names:
            - "rogue*"
```
```sh
kubectl apply -f rogue-exception.yaml
kubectl get policyexception -A
```

It is accepted — it satisfies the hygiene policy, and it is a structurally valid object. Nothing warns you that it will never do anything.

---

## Step 7: Prove the Scoping Holds

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rogue-pod
  namespace: prod-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF
```
```text
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

resource Pod/prod-ns/rogue-pod was blocked due to the following policies

prod-require-limits:
  check-limits: 'validation error: Every container must set ...'
```

Correct policy name, correct rule names, correct match block — and no effect whatsoever, because the object is not in the namespace Kyverno was told to honour exceptions from. This is the control that stops a namespace owner from writing themselves out of a cluster-wide policy.

---

## Step 8: Audit What Is Actually Exempted

```sh
sleep 90
kubectl get polr -A \
  -o jsonpath='{range .items[*]}{.scope.kind}{"/"}{.scope.name}{range .results[?(@.result=="skip")]}{"  "}{.policy}{"/"}{.rule}{"  <- "}{.properties.exceptions}{"\n"}{end}{end}'
```
```text
Deployment/payments-api  prod-require-limits/autogen-check-limits  <- allow-payments-api
Pod/payments-api-5f7c...  prod-require-limits/check-limits  <- allow-payments-api
```

Two exceptions exist in the cluster; exactly one appears here. That gap between `kubectl get policyexception -A` and the reports is the reason to audit exemptions from the reports: the object list tells you what people intended, and the reports tell you what is actually true.

Once `payments-api` is running, `rogue-pod` is absent, and the report shows the `skip` naming `allow-payments-api`, run the local validation suite to pass the capstone!
