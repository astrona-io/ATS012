# Solution Walkthrough

---

## Step 1: Find and Scrape the Endpoint

```sh
kubectl get svc -n kyverno
```
```text
NAME                                     TYPE        CLUSTER-IP      PORT(S)
kyverno-background-controller-metrics    ClusterIP   10.96.180.9     8000/TCP
kyverno-cleanup-controller               ClusterIP   10.96.77.132    443/TCP
kyverno-cleanup-controller-metrics       ClusterIP   10.96.55.3      8000/TCP
kyverno-reports-controller-metrics       ClusterIP   10.96.4.88      8000/TCP
kyverno-svc                              ClusterIP   10.96.121.44    443/TCP
kyverno-svc-metrics                      ClusterIP   10.96.14.201    8000/TCP
```

Four metrics Services, all on 8000. The admission controller's is `kyverno-svc-metrics` — not `kyverno-admission-controller-metrics`, which does not exist.

```sh
kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics | head -20
kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics | grep -c '^kyverno_'
```

A port-forward works too, if you prefer reading it locally:
```sh
kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8000:8000 &
curl -s http://localhost:8000/metrics | grep '^kyverno_info'
```

---

## Step 2: Apply the Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: metrics-demo-limits
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
              - metrics-ns
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
kubectl apply -f metrics-demo-limits.yaml
```

---

## Step 3: Find It in the Inventory Metric

```sh
kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
  | grep '^kyverno_policy_rule_info_total' | grep metrics-demo-limits
```
```text
kyverno_policy_rule_info_total{policy_background_mode="true",policy_name="metrics-demo-limits",policy_type="cluster",policy_validation_mode="enforce",rule_name="check-limits",rule_type="validate"} 1
```

The value is `1` — this is a gauge reporting "this rule exists", not a count of anything. Note that autogen's generated rules show up here too, so a Pod-scoped policy contributes several series.

---

## Step 4: The Admitted Pod

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: metrics-pass-pod
  namespace: metrics-ns
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

## Step 5: The Rejected Pod

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: metrics-fail-pod
  namespace: metrics-ns
spec:
  containers:
    - name: app
      image: nginx:alpine
EOF
```
```text
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

resource Pod/metrics-ns/metrics-fail-pod was blocked due to the following policies

metrics-demo-limits:
  check-limits: 'validation error: Every container must set ...'
```

---

## Step 6: Both Outcomes in the Results Metric

```sh
kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
  | grep '^kyverno_policy_results' | grep metrics-demo-limits
```
```text
kyverno_policy_results_total{policy_background_mode="true",policy_name="metrics-demo-limits",policy_type="cluster",policy_validation_mode="enforce",resource_kind="Pod",resource_request_operation="create",rule_execution_cause="admission_request",rule_name="check-limits",rule_result="pass",rule_type="validate"} 1
kyverno_policy_results_total{policy_background_mode="true",policy_name="metrics-demo-limits",policy_type="cluster",policy_validation_mode="enforce",resource_kind="Pod",resource_request_operation="create",rule_execution_cause="admission_request",rule_name="check-limits",rule_result="fail",rule_type="validate"} 1
```

Two series, differing only in `rule_result`. Both carry `rule_execution_cause="admission_request"` — these came from live traffic, not from a background scan. That label is what stops an hourly scan's re-confirmation of old violations from looking like a deploy incident.

Note the metric name on the wire is `kyverno_policy_results_total`, while the documentation calls it `kyverno_policy_results`. Kyverno instruments with OpenTelemetry and its Prometheus exporter appends `_total` to counters; grep the prefix and you match either spelling.

Also note what is *not* in those label sets: there is no `resource_namespace`. That dimension ships disabled — Module 2 is about turning it back on and what that costs.

---

## Step 7: Admission Request Volume

```sh
kubectl exec metrics-probe -- curl -s http://kyverno-svc-metrics.kyverno.svc:8000/metrics \
  | grep '^kyverno_admission_requests_total'
```
```text
kyverno_admission_requests_total{request_allowed="true",resource_kind="Pod",resource_request_operation="create"} 4
kyverno_admission_requests_total{request_allowed="false",resource_kind="Pod",resource_request_operation="create"} 1
```

The `request_allowed="false"` series is your rejected Pod, counted. This is the metric you would put a rate alert on: a sudden climb means a policy rollout is blocking something real.

Once both result series are present, run the local validation suite to pass the lab!
