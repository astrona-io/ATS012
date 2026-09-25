# Solution Walkthrough

---

## Step 1: Configure Metrics

```sh
kubectl -n kyverno patch configmap kyverno-metrics --type=merge --patch-file=/dev/stdin <<'EOF'
data:
  namespaces: '{"exclude":["ci-ns"],"include":[]}'
  bucketBoundaries: '0.02, 0.2, 2'
  metricsExposure: '{"kyverno_admission_requests_total":{"disabledLabelDimensions":["resource_namespace"]},"kyverno_admission_review_duration_seconds":{"disabledLabelDimensions":["resource_namespace"]},"kyverno_cleanup_controller_deletedobjects_total":{"disabledLabelDimensions":["resource_namespace","policy_namespace"]},"kyverno_policy_execution_duration_seconds":{"disabledLabelDimensions":["resource_namespace","resource_request_operation"]},"kyverno_policy_results_total":{"disabledLabelDimensions":[]},"kyverno_policy_rule_info_total":{"disabledLabelDimensions":["resource_namespace","policy_namespace"]}}'
EOF
kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.namespaces}{"\n"}{.data.bucketBoundaries}{"\n"}'
```

---

## Step 2: Restart the Admission Controller

```sh
kubectl -n kyverno rollout restart deployment kyverno-admission-controller
kubectl -n kyverno rollout status deployment/kyverno-admission-controller --timeout=180s
```

Instruments — their label sets and their bucket boundaries — are built at process start. Doing this before generating traffic also means the counters you are about to read start from a clean zero.

---

## Step 3: Apply the Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: capstone-metrics-limits
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
              - svc-a-ns
              - ci-ns
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
kubectl apply -f capstone-metrics-limits.yaml
```

One rule, both namespaces, no distinction whatsoever. Everything that follows is the metrics configuration doing its job, not the policy.

---

## Steps 4–6: Generate Traffic

```sh
# admitted
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: svc-a-ok
  namespace: svc-a-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
      resources:
        limits:
          cpu: "100m"
          memory: "128Mi"
EOF

# rejected, in the measured namespace
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: svc-a-bad
  namespace: svc-a-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF

# rejected, in the unmeasured namespace
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: ci-bad
  namespace: ci-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF
```

Both `svc-a-bad` and `ci-bad` are rejected with the same message from the same rule. Confirm:
```sh
kubectl get pods -n svc-a-ns
kubectl get pods -n ci-ns
```

---

## Step 7: Prove It All From the Endpoint

```sh
M="kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics"
```

**The policy is in the inventory, in enforce mode:**
```sh
$M | grep '^kyverno_policy_rule_info_total' | grep capstone-metrics-limits
```
```text
kyverno_policy_rule_info_total{policy_background_mode="true",policy_name="capstone-metrics-limits",policy_type="cluster",policy_validation_mode="enforce",rule_name="check-limits",rule_type="validate"} 1
```

**Both outcomes attributed to svc-a-ns:**
```sh
$M | grep '^kyverno_policy_results' | grep 'resource_namespace="svc-a-ns"'
```
```text
kyverno_policy_results_total{...,resource_namespace="svc-a-ns",rule_result="pass",...} 1
kyverno_policy_results_total{...,resource_namespace="svc-a-ns",rule_result="fail",...} 1
```

**Nothing anywhere mentions ci-ns:**
```sh
$M | grep -c 'ci-ns'
```
```text
0
```

**Rejections were counted:**
```sh
$M | grep '^kyverno_admission_requests_total' | grep 'request_allowed="false"'
```

**The custom buckets are live:**
```sh
$M | grep '^kyverno_admission_review_duration_seconds_bucket' | grep -o 'le="[^"]*"' | sort -u
```
```text
le="+Inf"
le="0.02"
le="0.2"
le="2"
```

Three boundaries plus `+Inf`, and no sign of the fifteen defaults.

---

## The Point of the Exercise

You now have a cluster where one namespace is measured in full per-namespace detail and another is not measured at all, while both are policed identically and both would appear in a `PolicyReport` if they had a violating resource that survived admission. Enforcement, reporting and measurement are three separate systems with three separate configurations — and knowing which one to reach for is most of what the Policy Management domain is actually about.

Once every check above holds, run the local validation suite to pass the capstone!
