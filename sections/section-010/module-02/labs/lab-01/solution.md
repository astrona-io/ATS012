# Solution Walkthrough

The order matters here: configure the pipeline first, then apply the policy. If you apply the policy first, `quiet-ns` gets scanned before your filter is in place and you will be chasing reports that should never have existed.

---

## Step 1: Read the Current Settings

```sh
kubectl get deployment kyverno-reports-controller -n kyverno \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -E 'background|ResourceFilters'
```
```text
"--backgroundScan=true"
"--backgroundScanWorkers=2"
"--backgroundScanInterval=1h"
"--skipResourceFilters=true"
```

Two defaults to understand before touching anything: scans run **hourly**, and the reports controller **ignores** `resourceFilters` (`skipResourceFilters=true` means "skip applying the filters").

---

## Step 2: Filter quiet-ns Out of Policy Processing

Read the current value first so you can keep the defaults:
```sh
kubectl get configmap kyverno -n kyverno -o jsonpath='{.data.resourceFilters}' > /tmp/filters.txt
head -5 /tmp/filters.txt
```

Append your entry and write the whole key back as a YAML merge patch:
```sh
printf '\n[*/*,quiet-ns,*]' >> /tmp/filters.txt
kubectl -n kyverno patch configmap kyverno --type=merge --patch-file=/dev/stdin <<EOF
data:
  resourceFilters: |-
$(sed 's/^/    /' /tmp/filters.txt)
EOF
kubectl get configmap kyverno -n kyverno -o jsonpath='{.data.resourceFilters}' | grep quiet-ns
```

The `sed` call indents every line of the saved filter list by four spaces so it sits correctly under the `|-` block scalar. A merge patch replaces only the keys you name, so the ConfigMap's other keys (`webhooks`, `excludeGroups`, …) are left alone.

> Dropping the default entries here is the classic way to break a cluster with a one-line change: without `[*/*,kyverno,*]` and `[Event,*,*]`, Kyverno starts evaluating its own objects and every Event in the cluster.

---

## Step 3: Patch the Reports Controller

```sh
kubectl -n kyverno patch deployment kyverno-reports-controller --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--skipResourceFilters=false"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--backgroundScanInterval=1m"}
]'
kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s
```

Appending with `args/-` puts each flag at the end of the list; Kyverno takes the last occurrence, so you override the manifest's value without needing to know its index.

---

## Step 4: Apply the Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: audit-resource-limits
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
              - legacy-ns
              - quiet-ns
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
kubectl apply -f audit-resource-limits.yaml
```

Note that the rule matches **both** namespaces. Nothing in the policy treats `quiet-ns` differently — the exclusion is entirely an installation-level decision.

---

## Step 5: Watch legacy-ns Fill In

```sh
kubectl get polr -n legacy-ns -o wide
```

Nothing yet? That is expected — the pre-existing Deployment generates no admission request, so it waits for a scan. With the interval at `1m`, give it a couple of minutes:

```sh
sleep 90
kubectl get polr -n legacy-ns -o wide
```
```text
NAME                                   KIND         NAME         PASS   FAIL   WARN   ERROR   SKIP   AGE
6c9e2a31-...                           Deployment   legacy-api   0      1      0      0       0      40s
b2f77c05-...                           Pod          legacy-api-6d9...  0   1   0      0       0      40s
```

And the workload itself is untouched:
```sh
kubectl get deployment legacy-api -n legacy-ns
kubectl get pods -n legacy-ns
```

Background scanning only ever reports. It never blocks, deletes, or restarts anything, no matter what `validationFailureAction` says.

---

## Step 6: Confirm quiet-ns Stays Quiet

```sh
kubectl get polr -n quiet-ns
```
```text
No resources found in quiet-ns namespace.
```

Same rule, same kind of violation, same policy — and no report, because the reports controller now obeys `resourceFilters` and `quiet-ns` is filtered out. Flip `--skipResourceFilters` back to `true` and reports for `quiet-ns` reappear on the next scan; that one flag is the whole difference between "excluded from enforcement" and "excluded from the record".

Once `legacy-ns` shows a failing report and `quiet-ns` shows none, run the local validation suite to pass the lab!
