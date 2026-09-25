# Solution Walkthrough

---

## Step 1: Read the Shipped Configuration

```sh
kubectl get configmap kyverno-metrics -n kyverno -o yaml
kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.namespaces}{"\n"}'
kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.bucketBoundaries}{"\n"}'
```
```text
{"exclude":[],"include":[]}
0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 15, 20, 25, 30
```

And confirm the missing label on the endpoint:
```sh
kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
  | grep '^kyverno_policy_results' | head -2
```

No `resource_namespace` anywhere in those label sets — that dimension ships disabled.

---

## Step 2: Patch All Three Keys

A YAML patch file keeps the JSON readable; patching with `-p '{...}'` would mean escaping every quote inside a JSON string inside a JSON document.

```sh
kubectl -n kyverno patch configmap kyverno-metrics --type=merge --patch-file=/dev/stdin <<'EOF'
data:
  namespaces: '{"exclude":["excluded-ns"],"include":[]}'
  bucketBoundaries: '0.01, 0.1, 1, 5, 10'
  metricsExposure: '{"kyverno_admission_requests_total":{"disabledLabelDimensions":["resource_namespace"]},"kyverno_admission_review_duration_seconds":{"disabledLabelDimensions":["resource_namespace"]},"kyverno_cleanup_controller_deletedobjects_total":{"disabledLabelDimensions":["resource_namespace","policy_namespace"]},"kyverno_policy_execution_duration_seconds":{"disabledLabelDimensions":["resource_namespace","resource_request_operation"]},"kyverno_policy_results_total":{"disabledLabelDimensions":[]},"kyverno_policy_rule_info_total":{"disabledLabelDimensions":["resource_namespace","policy_namespace"]}}'
EOF
kubectl get configmap kyverno-metrics -n kyverno -o jsonpath='{.data.namespaces}{"\n"}{.data.bucketBoundaries}{"\n"}'
```

Every `metricsExposure` entry is the shipped default except `kyverno_policy_results_total`, whose disabled list is now empty. That matters: a merge patch replaces the whole string, so anything you leave out silently reverts to the code's defaults rather than to the values Kyverno shipped.

---

## Step 3: Restart to Rebuild the Instruments

```sh
kubectl -n kyverno rollout restart deployment kyverno-admission-controller
kubectl -n kyverno rollout status deployment/kyverno-admission-controller --timeout=180s
```

Label sets and bucket boundaries are fixed when the instruments are created at process start — editing the ConfigMap alone changes nothing on a running controller. The side effect is that every counter restarts at zero, which is exactly why you do the configuration first and generate traffic afterwards.

---

## Step 4: Apply the Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: metrics-config-limits
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
              - watched-ns
              - excluded-ns
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
kubectl apply -f metrics-config-limits.yaml
```

`Audit`, so both Pods in the next step are admitted and both are evaluated. The policy treats the two namespaces identically — any difference you see in the metrics comes purely from the metrics configuration.

---

## Step 5: Generate Traffic in Both Namespaces

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: watched-pod
  namespace: watched-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: excluded-pod
  namespace: excluded-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF
kubectl get pods -n watched-ns
kubectl get pods -n excluded-ns
```

---

## Step 6: Prove Attribution and Exclusion

```sh
kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
  | grep '^kyverno_policy_results' | grep 'resource_namespace='
```
```text
kyverno_policy_results_total{...,policy_name="metrics-config-limits",resource_kind="Pod",resource_namespace="watched-ns",rule_result="fail",...} 1
```

`watched-ns` is now attributable. Now the exclusion:

```sh
kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
  | grep -c 'excluded-ns'
```
```text
0
```

Zero series mention `excluded-ns` — and yet:

```sh
kubectl get polr -n excluded-ns -o wide
```

…the PolicyReport for `excluded-pod` is right there. The namespace is still fully evaluated and still reported on. You stopped counting it, not policing it. Those are different systems with different ConfigMaps: `namespaces` in `kyverno-metrics` controls measurement, `resourceFilters` in `kyverno` controls evaluation.

---

## Step 7: Prove the New Buckets

```sh
kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
  | grep '^kyverno_admission_review_duration_seconds_bucket' | grep -o 'le="[^"]*"' | sort -u
```
```text
le="+Inf"
le="0.01"
le="0.1"
le="1"
le="10"
le="5"
```

Five boundaries plus `+Inf`, exactly what you configured — and `le="0.025"`, a default boundary, is gone. Fewer buckets means fewer series; the cost is that a p99 computed from this can only place the value somewhere between two much wider boundaries.

Once all three changes are visible on the endpoint, run the local validation suite to pass the lab!
