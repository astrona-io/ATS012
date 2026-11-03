# Severity, Categories & Consuming Reports - Playground

- **ID:** PLAYGROUND
- **Slug:** ats-012-playground-010-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground - clean environment, no task, no grading

A kind cluster with Kyverno v1.13.2 installed. Two annotated Audit policies (`severity` high and medium) judge three Pods across `team-red` and `team-blue`. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-012-playground-010-03
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-012-playground-010-03`), not the config path. `astrona submit` and `astrona test` do not apply - there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (bootstrap steps) |
| `bootstrap/01-install-kyverno.sh` | Installs Kyverno v1.13.2 and waits for its four controllers |
| `bootstrap/02-seed.sh` | Creates the starting state described above |
| `docs/overview.md` | What the environment contains and ideas to try |

> UNTESTED: built and statically checked only. It has not been run with `astrona run`.
