# Solution Walkthrough

Three policies, three different reporting behaviours, on one cluster. Work top to bottom.

---

## Step 1: Make Background Scans Lab-Speed

```sh
kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
]'
kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s
```

---

## Step 2: The Scored Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: capstone-require-limits
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
              - prod-ns
              - staging-ns
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

## Step 3: The Advisory Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: capstone-require-team-label
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
              - prod-ns
              - staging-ns
      validate:
        message: "Every Pod should carry a 'team' label."
        pattern:
          metadata:
            labels:
              team: "?*"
```

Both workloads violate this one. Because of `scored: "false"`, neither violation increments `summary.fail` — they land in `summary.warn`.

---

## Step 4: The Admission-Only Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: capstone-admission-only
spec:
  validationFailureAction: Audit
  background: false
  rules:
    - name: check-reviewed-label
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - prod-ns
      validate:
        message: "Pods in prod-ns must carry a 'reviewed' label."
        pattern:
          metadata:
            labels:
              reviewed: "?*"
```

```sh
kubectl apply -f capstone-require-limits.yaml
kubectl apply -f capstone-require-team-label.yaml
kubectl apply -f capstone-admission-only.yaml
kubectl get clusterpolicy
```

`background: false` sits at `spec` level, not on the rule — it is a property of the whole policy. Setting it here is what keeps this policy out of every background scan.

---

## Step 5: Read the Reporting State

Give the scan a cycle or two, then:

```sh
sleep 90
kubectl get polr -n prod-ns -o wide
kubectl get polr -n staging-ns -o wide
```

```text
# prod-ns
NAME           KIND         NAME          PASS   FAIL   WARN   ERROR   SKIP
9a3f...        Deployment   billing-api   0      1      1      0       0
c410...        Pod          billing-api-7c...  0  1     1      0       0

# staging-ns
NAME           KIND         NAME           PASS   FAIL   WARN   ERROR   SKIP
71bd...        Deployment   checkout-api   1      0      1      0       0
```

`prod-ns` fails the limits rule and warns on the team label. `staging-ns` passes the limits rule — it already sets them — and only warns. Same two policies, different outcomes, entirely because of the workloads' own state.

And nothing was disturbed:
```sh
kubectl get deployment -A | grep -E 'billing-api|checkout-api'
```

---

## Step 6: Prove the Admission-Only Policy Is Absent From Background Reports

```sh
uid=$(kubectl get deployment billing-api -n prod-ns -o jsonpath='{.metadata.uid}')
kubectl get polr "$uid" -n prod-ns -o jsonpath='{range .results[*]}{.policy}{"\n"}{end}' | sort -u
```
```text
capstone-require-limits
capstone-require-team-label
```

`capstone-admission-only` is not in the list. The policy is live, the Pod is in scope, the label is missing — and the background scan still never evaluated it, because `spec.background: false` excludes the policy from scanning entirely.

---

## Step 7: Prove It Is Live at Admission Time

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: reviewed-check-pod
  namespace: prod-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
      resources:
        limits:
          cpu: "100m"
          memory: "128Mi"
EOF
sleep 15
puid=$(kubectl get pod reviewed-check-pod -n prod-ns -o jsonpath='{.metadata.uid}')
kubectl get polr "$puid" -n prod-ns -o jsonpath='{range .results[*]}{.policy}{" -> "}{.result}{"\n"}{end}'
```
```text
capstone-admission-only -> fail
capstone-require-limits -> pass
capstone-require-team-label -> warn
```

There it is. The same policy that was invisible to the background scan produced a `fail` the instant a resource went through admission — which is exactly what `spec.background: false` means: admission only, never history.

Once all three states check out, run the local validation suite to pass the capstone!
