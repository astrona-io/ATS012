# Solution Walkthrough

Follow these steps to get both policies live and read the reports they produce.

---

## Step 1: Apply the Scored Policy

Create `require-resource-limits.yaml`:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
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
              - platform-ns
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

`?*` is Kyverno's "any non-empty value" wildcard — it asserts the field exists and is not empty, without caring what the value is.

---

## Step 2: Apply the Advisory Policy

Create `require-team-label.yaml`. The annotation is what makes this policy advisory:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label
  annotations:
    policies.kyverno.io/scored: "false"
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-team-label
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - platform-ns
      validate:
        message: "Every Pod must carry a 'team' label."
        pattern:
          metadata:
            labels:
              team: "?*"
```
```sh
kubectl apply -f require-team-label.yaml
kubectl get clusterpolicy
```

---

## Step 3: Create the Compliant Pod

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: platform-ns
  labels:
    team: platform
spec:
  containers:
    - name: app
      image: nginx:alpine
      resources:
        limits:
          cpu: "100m"
          memory: "128Mi"
EOF
```

---

## Step 4: Create the Violating Pod

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: violator-pod
  namespace: platform-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF
```

This one is **admitted**:
```sh
kubectl get pods -n platform-ns
```
Both policies are `Audit`, so nothing blocks. The violation is recorded instead of rejected — which is the entire point of this lab.

---

## Step 5: Find the Report

Reports are named after the reported resource's UID, so never guess:
```sh
kubectl get polr -n platform-ns -o wide
```
```text
NAME                                   KIND   NAME            PASS   FAIL   WARN   ERROR   SKIP   AGE
1f0a9e33-...                           Pod    compliant-pod   2      0      0      0       0      20s
c7b41d90-...                           Pod    violator-pod    0      1      1      0       0      12s
```

Or go straight there from the Pod:
```sh
uid=$(kubectl get pod violator-pod -n platform-ns -o jsonpath='{.metadata.uid}')
kubectl get polr "$uid" -n platform-ns -o yaml
```

If the report is not there yet, give the aggregation step a few seconds and re-run — the admission path is fast, but it is not instantaneous.

---

## Step 6: Confirm the Counters

```sh
uid=$(kubectl get pod violator-pod -n platform-ns -o jsonpath='{.metadata.uid}')
kubectl get polr "$uid" -n platform-ns -o jsonpath='{.summary}{"\n"}'
```
```text
{"error":0,"fail":1,"pass":0,"skip":0,"warn":1}
```

One `fail` from `require-resource-limits` and one `warn` from `require-team-label`. Both Pods violated an equal number of rules; the only reason one lands in `fail` and the other in `warn` is the `policies.kyverno.io/scored: "false"` annotation on the second policy.

Now the compliant Pod:
```sh
cuid=$(kubectl get pod compliant-pod -n platform-ns -o jsonpath='{.metadata.uid}')
kubectl get polr "$cuid" -n platform-ns -o jsonpath='{.summary}{"\n"}'
```
```text
{"error":0,"fail":0,"pass":2,"skip":0,"warn":0}
```

---

## Step 7: Print Only the Failures

```sh
kubectl get polr "$uid" -n platform-ns \
  -o jsonpath='{range .results[?(@.result=="fail")]}{.policy}{"/"}{.rule}{"  "}{.message}{"\n"}{end}'
```
```text
require-resource-limits/check-limits  validation error: Every container must set resources.limits.cpu and resources.limits.memory. rule check-limits failed at path /spec/containers/0/resources/limits/
```

Swap `"fail"` for `"warn"` to see the advisory finding instead. Once both reports look right, run the local validation suite to pass the lab!
