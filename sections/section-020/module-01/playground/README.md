# Enabling & Writing a PolicyException - Playground

- **ID:** PLAYGROUND
- **Slug:** ats-012-playground-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground - clean environment, no task, no grading

A kind cluster with Kyverno v1.13.2 installed. `legacy-api` runs without limits in `legacy-ns`, an Enforce policy blocks new such Pods, and PolicyExceptions are still disabled. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-012-playground-020-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-012-playground-020-01`), not the config path. `astrona submit` and `astrona test` do not apply - there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (bootstrap steps) |
| `bootstrap/01-install-kyverno.sh` | Installs Kyverno v1.13.2 and waits for its four controllers |
| `bootstrap/02-seed.sh` | Creates the starting state described above |
| `docs/overview.md` | What the environment contains and ideas to try |

> UNTESTED: built and statically checked only. It has not been run with `astrona run`.
