# Solution Walkthrough

---

## Step 1: Apply the Enforce Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
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
              - legacy-ns
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

The running `legacy-api` is untouched — `Enforce` acts at admission time, and nothing is being admitted for a Pod that already exists.

---

## Step 2: Prove It Blocks

```sh
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: new-api
  namespace: legacy-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: new-api
  template:
    metadata:
      labels:
        app: new-api
    spec:
      containers:
        - name: app
          image: nginx:alpine
EOF
```
```text
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

resource Deployment/legacy-ns/new-api was blocked due to the following policies

require-resource-limits:
  autogen-check-limits: 'validation error: Every container must set ...'
```

Read the rule name in that error: **`autogen-check-limits`**, not `check-limits`. You wrote one rule matching Pods; autogen generated the Deployment-facing copy, and that copy is what rejected you. Remember this for Step 5.

---

## Step 3: Enable Exceptions on Both Controllers

```sh
for d in kyverno-admission-controller kyverno-reports-controller; do
  kubectl -n kyverno patch deployment "$d" --type=json -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enablePolicyException=true"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--exceptionNamespace=platform-ns"}
  ]'
  kubectl -n kyverno rollout status "deployment/$d" --timeout=180s
done
```

The admission controller decides whether the workload is admitted. The reports controller decides whether the report says `skip` instead of `fail`. Skip either one and enforcement and the record disagree.

---

## Step 4: Speed Up Background Scans

```sh
kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
]'
kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s
```

---

## Step 5: Write the Exception

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: allow-legacy-api
  namespace: platform-ns
spec:
  exceptions:
    - policyName: require-resource-limits
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
            - legacy-ns
          names:
            - "legacy-api*"
```
```sh
kubectl apply -f allow-legacy-api.yaml
kubectl get policyexception -n platform-ns
```

Three details are doing the work here:

*   **Both rule names.** `check-limits` covers bare Pods; `autogen-check-limits` covers the Deployment — which is what Step 2 showed you was blocking.
*   **Both kinds.** The admission request being judged is a `Deployment` request when the controller is updated, and a `Pod` request when the ReplicaSet spawns replicas.
*   **The trailing `*`.** The Pods are named `legacy-api-7c9f4b8d6-x2k9p`. An exact `legacy-api` match would exempt the Deployment and leave every Pod blocked.

---

## Step 6: Force a Re-roll

```sh
kubectl -n legacy-ns patch deployment legacy-api -p \
  '{"spec":{"template":{"metadata":{"annotations":{"force-reroll":"1"}}}}}'
kubectl -n legacy-ns rollout status deployment/legacy-api --timeout=180s
kubectl get pods -n legacy-ns
```

A brand-new Pod, still with no resource limits, admitted under an `Enforce` policy. If the rollout hangs instead, describe the ReplicaSet — a blocked Pod creation shows up there as an event, and the usual cause is a missing `autogen-` rule name or a missing `*`.

---

## Step 7: Read the Exemption in the Report

```sh
sleep 90
kubectl get polr -n legacy-ns -o wide
kubectl get polr -n legacy-ns \
  -o jsonpath='{range .items[*]}{.scope.kind}{"/"}{.scope.name}{range .results[?(@.result=="skip")]}{"  "}{.rule}{" <- "}{.properties.exceptions}{"\n"}{end}{end}'
```
```text
Deployment/legacy-api  autogen-check-limits <- allow-legacy-api
Pod/legacy-api-6f8b...  check-limits <- allow-legacy-api
```

That line is the whole point of using an exception instead of quietly widening the policy: the rule that was waived, the resource it was waived for, and the named object that waived it — all in the compliance record.

Once the re-rolled Pod is running and the report shows `skip`, run the local validation suite to pass the lab!
