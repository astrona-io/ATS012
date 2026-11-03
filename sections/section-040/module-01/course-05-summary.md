# Summary

The Kyverno CLI evaluates policies against local files, so a policy can be checked before it reaches a cluster.

## What you learned

`kyverno apply` runs a policy against resource files and prints the five result counts. It does not write anything to a cluster, and it does not compare the result with an expectation. `kyverno test` reads `kyverno-test.yaml` files and compares each expected result with the actual one. It fails on a missing result, an unexpected result or a different value, and it exits non-zero so a pipeline can stop.

A test names the policy, the rule, the resource kind and the resource names, and it expects one of the five result values. Rules produced by autogeneration have an `autogen-` prefix. Variables come from a values file, user data comes from a user information file, mutate rules use `patchedResource` and generate rules use `generatedResource`.

The key facts to remember are these:

- Use `kyverno test` as the gate, because it compares results with expectations.
- Include at least one resource that must fail.
- Pin the CLI to the cluster's Kyverno minor version.
- CLI tests do not replace tests on a real cluster.

<!-- astrona:playground:destroy -->
