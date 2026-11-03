# Solution

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-040/capstone/labs/lab-01
```

## Step 1: Write the expected mutated Pod

```sh
cd /opt/kyverno-capstone
cat > patched-web.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: default
  labels:
    app: web
    team: platform
spec:
  containers:
    - name: app
      image: nginx:1.27
YAML
```

## Step 2: Write the test

```sh
cat > kyverno-test.yaml <<'YAML'
apiVersion: cli.kyverno.io/v1alpha1
kind: Test
metadata:
  name: capstone-tests
policies:
  - disallow-latest.yaml
  - add-team-label.yaml
resources:
  - resources.yaml
results:
  - policy: disallow-latest-tag
    rule: check-tag
    kind: Pod
    resources:
      - web
    result: pass
  - policy: disallow-latest-tag
    rule: check-tag
    kind: Pod
    resources:
      - legacy
    result: fail
  - policy: add-team-label
    rule: add-team
    kind: Pod
    resources:
      - web
    patchedResource: patched-web.yaml
    result: pass
YAML
```

## Step 3: Write the runner

```sh
cat > run-tests.sh <<'SH'
#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
kyverno test .
SH
bash run-tests.sh
echo $?
```

The exit code is 0. If you change `platform` to another value in `add-team-label.yaml`, the same command exits non-zero, because the mutated Pod no longer equals `patched-web.yaml`.

```sh
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-040/capstone/labs/lab-01 --keep
```
