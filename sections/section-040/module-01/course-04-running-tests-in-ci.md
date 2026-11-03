# Running Tests in CI

A test that nobody runs protects nothing. This part shows how to run `kyverno test` automatically, how to control which tests run and how to read the result in a pipeline.

## Exit codes

`kyverno test` exits with code 0 when every expectation is met and with a non-zero code when any test fails. A CI job can run the command as a step and fail the build on a non-zero code, with no extra parsing.

```sh
kyverno test ./policies
```

The command searches the path recursively for `kyverno-test.yaml` files, so one command covers a whole repository.

## Choosing what to run

- `--file-name` (`-f`) changes the name to search for, when your files are not called `kyverno-test.yaml`.
- `--test-case-selector` runs part of a test. It takes a comma-separated list such as `policy=require-limits,rule=check-limits,resource=bad-pod`.
- `--detailed-results` prints the result of every rule, not only the table.
- `--fail-only` prints only failing rows, which helps in large suites.
- `--remove-color` removes colour codes so the output reads well in a log.
- `--git-branch` reads the test files from a Git repository branch.

## A pipeline step

A typical step installs the CLI at a pinned version and runs the tests.

```sh
curl -sLO https://github.com/kyverno/kyverno/releases/download/v1.13.2/kyverno-cli_v1.13.2_linux_x86_64.tar.gz
tar -xzf kyverno-cli_v1.13.2_linux_x86_64.tar.gz kyverno
./kyverno test .
```

Pin the CLI to the same minor version as the cluster. A newer CLI may evaluate a feature that the cluster does not have, and an older one may not know a field.

## Repository layout

Keep each policy next to its test. One layout is a directory per policy that holds `policy.yaml`, `resources.yaml` and `kyverno-test.yaml`. A reviewer then sees the policy change and the test change in the same pull request.

## What tests cannot show

The CLI does not talk to the API server unless you use `--cluster`. It cannot show how admission, background scans, exceptions or the reports controller behave in a real cluster. Treat CLI tests as the first gate. Real behaviour still needs a cluster test, which is what the module labs in the earlier sections cover.

> [!TIP]
> **Try it - make a test fail on purpose**
>
> Run `kyverno test .` in the playground and note the exit code with `echo $?`. Change one expected result so it is wrong, run the command again and compare the exit codes.

## Common pitfalls

- Running `kyverno apply` as the only gate. It reports what a policy does, but it does not compare the result with what you expected.
- Using a different CLI version in CI from the one that produced the sample outputs.
- Writing only passing cases. A policy test needs at least one resource that must fail, or the test would pass even if the rule matched nothing.

You can now write, run and automate tests for a policy before it reaches a cluster.
