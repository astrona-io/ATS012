#!/usr/bin/env bash
set -eu

mkdir -p /opt/kyverno-capstone
cd /opt/kyverno-capstone

cat > disallow-latest.yaml <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-tag
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Images must not use the latest tag."
        pattern:
          spec:
            containers:
              - image: "!*:latest"
YAML

cat > add-team-label.yaml <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-team-label
spec:
  rules:
    - name: add-team
      match:
        any:
          - resources:
              kinds:
                - Pod
              selector:
                matchLabels:
                  app: web
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(team): platform
YAML

cat > resources.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: default
  labels:
    app: web
spec:
  containers:
    - name: app
      image: nginx:1.27
---
apiVersion: v1
kind: Pod
metadata:
  name: legacy
  namespace: default
spec:
  containers:
    - name: app
      image: nginx:latest
YAML

chmod -R a+rwX /opt/kyverno-capstone
echo "Capstone policies and resources are in /opt/kyverno-capstone."
