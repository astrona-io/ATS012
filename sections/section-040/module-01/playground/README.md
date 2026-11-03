# Testing Policies with the Kyverno CLI - Playground

- **ID:** PLAYGROUND
- **Slug:** ats-012-playground-040-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground - clean environment, no task, no grading

An environment with the Kyverno CLI v1.13.2 and a sample policy with two Pods in `/opt/kyverno-lab`. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-012-playground-040-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-012-playground-040-01`), not the config path. `astrona submit` and `astrona test` do not apply - there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (bootstrap steps) |
| `bootstrap/01-install-kyverno-cli.sh` | Downloads the Kyverno CLI v1.13.2 |
| `bootstrap/02-seed.sh` | Writes the sample policy and resources |
| `docs/overview.md` | What the environment contains and ideas to try |

> UNTESTED: built and statically checked only. It has not been run with `astrona run`.
