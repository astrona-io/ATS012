# Solution Walkthrough

---

## Step 1: The Policy Being Excepted

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: batch-require-limits
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
              - batch-ns
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
kubectl apply -f batch-require-limits.yaml
```

---

## Step 2: The Hygiene Policy Over Exceptions Themselves

Kyverno evaluates its own CRDs like any other resource, so a policy can require that every exemption arrives with an owner and an end date:

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
kubectl apply -f require-exception-metadata.yaml
```

`background: false` is deliberate. The rule's job is to stop a badly-formed exception at creation time; re-checking already-accepted exceptions every scan cycle would produce the same verdict forever and cost real API traffic.

---

## Step 3: Prove the Hygiene Policy Blocks

```sh
kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: sloppy-exception
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
EOF
```
```text
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

resource PolicyException/platform-ns/sloppy-exception was blocked due to the following policies

require-exception-metadata:
  check-owner-and-expiry: 'validation error: A PolicyException must carry ...'
```

An exemption with no owner and no end date is now impossible to create. That is governance implemented as a policy rather than as a wiki page.

---

## Step 4: The Narrow, Condition-Gated Exception

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: allow-optin-batch
  namespace: platform-ns
  annotations:
    exception.company.io/owner: "platform-team"
    exception.company.io/expires: "2026-12-31"
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
  conditions:
    all:
      - key: "{{ request.object.metadata.labels.exempt || '' }}"
        operator: Equals
        value: "true"
```
```sh
kubectl apply -f allow-optin-batch.yaml
kubectl get policyexception -n platform-ns
```

Two gates, doing different jobs. `match` says *which resources are candidates*: Pods in `batch-ns`. `conditions` says a candidate is only exempted if it *also* carries `exempt: "true"` right now. The `|| ''` fallback keeps a Pod with no labels at all from turning a missing key into an `error` result.

---

## Step 5: The Un-Opted-In Pod Is Still Blocked

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: no-optin
  namespace: batch-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF
```
```text
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

resource Pod/batch-ns/no-optin was blocked due to the following policies

batch-require-limits:
  check-limits: 'validation error: Every container must set ...'
```

The exception exists, the Pod is in the matched namespace and of the matched kind — and it is still blocked, because it never claimed the exemption.

---

## Step 6: The Opted-In Pod Is Admitted

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: with-optin
  namespace: batch-ns
  labels:
    exempt: "true"
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF
kubectl get pods -n batch-ns
```

Identical Pod spec, identical missing limits. The only difference is one label the workload's author had to write into their own manifest — which is exactly the point: the claim to an exemption now lives in the thing being exempted, where a code reviewer will see it.

---

## Step 7: Audit the Exemption From the Report

```sh
sleep 30
uid=$(kubectl get pod with-optin -n batch-ns -o jsonpath='{.metadata.uid}')
kubectl get polr "$uid" -n batch-ns \
  -o jsonpath='{range .results[*]}{.rule}{" -> "}{.result}{" ("}{.properties.exceptions}{")"}{"\n"}{end}'
```
```text
check-limits -> skip (allow-optin-batch)
```

Now sweep the whole cluster the way you would during a compliance review:

```sh
kubectl get polr -A \
  -o jsonpath='{range .items[*]}{.scope.kind}{"/"}{.scope.name}{range .results[?(@.result=="skip")]}{"  "}{.policy}{"/"}{.rule}{"  <- "}{.properties.exceptions}{"\n"}{end}{end}'
```

Every line is one live exemption, with the object responsible named. Once `no-optin` is absent, `with-optin` is running, and the report shows the `skip`, run the local validation suite to pass the lab!
