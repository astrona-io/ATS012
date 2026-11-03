#!/usr/bin/env bash
set -eu

mkdir -p /opt/kyverno-lab
cd /opt/kyverno-lab

cat > policy.yaml <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-limits
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
      validate:
        message: "Every container must set resources.limits.cpu and resources.limits.memory."
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    cpu: "?*"
                    memory: "?*"
YAML

cat > resources.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: good-pod
  namespace: default
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        limits:
          cpu: "100m"
          memory: "64Mi"
---
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: default
spec:
  containers:
    - name: app
      image: nginx:1.27
YAML

chmod -R a+rwX /opt/kyverno-lab
echo "Sample policy and resources are in /opt/kyverno-lab."
