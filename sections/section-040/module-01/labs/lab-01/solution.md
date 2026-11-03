# Solution

> UNTESTED: this lab was built and checked statically only. It has not been run with `astrona test`.

Solve this lab on `terminal`. Each step ends with `astrona submit`. The `--keep` flag keeps the lab running so you can continue after a failed check.

Start the lab if it is not running:

```sh
astrona run --git git@github.com:astrona-io/ATS012.git -c sections/section-040/module-01/labs/lab-01
```

## Step 1: Run the policy

```sh
cd /opt/kyverno-lab
kyverno apply policy.yaml --resource resources.yaml --detailed-results
```

`bad-pod` fails the rule `check-limits` because it has no limits. `good-pod` passes.

## Step 2: Write the test

```sh
cat > kyverno-test.yaml <<'YAML'
apiVersion: cli.kyverno.io/v1alpha1
kind: Test
metadata:
  name: require-limits-test
policies:
  - policy.yaml
resources:
  - resources.yaml
results:
  - policy: require-limits
    rule: check-limits
    kind: Pod
    resources:
      - good-pod
    result: pass
  - policy: require-limits
    rule: check-limits
    kind: Pod
    resources:
      - bad-pod
    result: fail
YAML
```

## Step 3: Run the test

```sh
kyverno test .
echo $?
```

Every row shows Pass and the exit code is 0.

```sh
astrona submit --git git@github.com:astrona-io/ATS012.git -c sections/section-040/module-01/labs/lab-01 --keep
```
