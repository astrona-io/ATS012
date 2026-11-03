# Labels on Kyverno Metrics

A metric name alone tells you very little. The labels on each series are what let you ask which policy, which rule and which kind of request. This chapter explains the labels on the two metrics you will query most, and what values they take.

## Labels on kyverno_policy_results_total

Each series of `kyverno_policy_results_total` is one unique combination of label values. In Kyverno v1.13 the labels are:

- `policy_validation_mode`: `enforce` or `audit`.
- `policy_type`: `cluster` for a `ClusterPolicy`, `namespaced` for a `Policy`.
- `policy_background_mode`: `true` or `false`, from `spec.background`.
- `policy_namespace`: the namespace of a `Policy`, or `-` for a `ClusterPolicy`.
- `policy_name`: the policy name.
- `resource_kind`: the kind of the resource that was evaluated, for example `Pod`.
- `resource_namespace`: the resource namespace. This label ships disabled, so it may be absent.
- `resource_request_operation`: `create`, `update`, `delete` or `connect`.
- `rule_name`: the rule name.
- `rule_result`: `pass`, `fail`, `warn`, `error` or `skip`.
- `rule_type`: `validate`, `mutate`, `generate` or `imageVerify`.
- `rule_execution_cause`: `admission_request` or `background_scan`.

Check the exact set on your cluster, because label names can change between releases. List them from the raw endpoint:

```sh
kubectl exec -n default metrics-probe -- \
  curl -s http://kyverno-svc-metrics.kyverno:8000/metrics \
  | grep '^kyverno_policy_results_total' | head -n 3
```

## Labels on admission metrics

`kyverno_admission_requests_total` counts requests that reach the Kyverno webhook. It carries resource labels such as `resource_kind`, `resource_namespace` and `resource_request_operation`. The duration histogram `kyverno_admission_review_duration_seconds` carries similar resource labels. Confirm the exact set on your endpoint.

Because these metrics do not carry a policy name, they tell you about the webhook as a whole. To find out which policy is responsible for a spike, move to `kyverno_policy_results_total` or `kyverno_policy_execution_duration_seconds`.

## Turning labels into questions

Filtering on labels uses curly braces. Grouping uses `by`. Some useful questions:

```promql
sum by (policy_name) (increase(kyverno_policy_results_total{rule_result="fail", policy_validation_mode="enforce"}[1h]))
sum by (rule_type) (increase(kyverno_policy_results_total[1h]))
sum by (rule_execution_cause) (increase(kyverno_policy_results_total{rule_result="fail"}[1h]))
```

The first finds enforce policies that blocked requests. The second shows the mix of validate, mutate, generate and image verification work. The third separates failures caused by new requests from failures found by background scans of existing resources.

A rule result of `fail` in `audit` mode does not block anything. It is recorded so that you can see what an enforce policy would do.

> [!TIP]
> **Try it - split failures by cause**
>
> Create a Pod without limits in `metrics-ns`, then fetch the endpoint again and compare the `rule_execution_cause` values on the `fail` series. A request made through the API server appears with the admission cause. A resource found later by a scan appears with the background cause.

## Common pitfalls

- Writing a query with a label name taken from memory. A wrong label name does not raise an error. It returns an empty result.
- Filtering on `resource_namespace` while the label is disabled in the metrics ConfigMap.
- Treating `warn` as a mild failure. It is an advisory result, not a failure.
- Summing over `rule_result` without a filter and calling the total "violations". The total includes passes.

## What you know now

You can read each label on the results metric, name its possible values and write queries that group and filter by them. The next step is to watch what happens when you change which of these labels exist.
