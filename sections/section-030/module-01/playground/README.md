# The Metrics Endpoint & Core Metric Families - Playground

- **ID:** PLAYGROUND
- **Slug:** ats-012-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground - clean environment, no task, no grading

A kind cluster with Kyverno v1.13.2 installed. A `metrics-probe` Pod with curl, a `metrics-demo-limits` Enforce policy and one passing Pod in `metrics-ns`. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-012-playground-030-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-012-playground-030-01`), not the config path. `astrona submit` and `astrona test` do not apply - there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (bootstrap steps) |
| `bootstrap/01-install-kyverno.sh` | Installs Kyverno v1.13.2 and waits for its four controllers |
| `bootstrap/02-seed.sh` | Creates the starting state described above |
| `docs/overview.md` | What the environment contains and ideas to try |

> UNTESTED: built and statically checked only. It has not been run with `astrona run`.
