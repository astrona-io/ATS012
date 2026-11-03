# Part 4 — Policy Reporter and Other Report Consumers

`kubectl` is enough for an administrator who investigates a problem. Teams that need a dashboard, history or alert messages use a tool that reads reports for them. This part explains what those tools do, installs Policy Reporter, and lists the limits that come from the report model itself.

## What a consumer adds

A report shows the current state. It does not keep history, it has no user interface and it sends no notifications. A consumer reads the report objects with the Kubernetes API and adds those things on top. Because it reads the same objects you read with `kubectl`, a consumer cannot show something that is not in a report.

Policy Reporter is an open-source project from the Kyverno community. It watches `PolicyReport` and `ClusterPolicyReport` objects and provides a web user interface, Prometheus metrics and notification targets such as Slack and email.

## Install Policy Reporter

Policy Reporter installs with Helm, the Kubernetes package manager. The command below adds the chart repository and installs the chart with the user interface enabled:

<!-- astrona:playground:renew -->

```sh
helm repo add policy-reporter https://kyverno.github.io/policy-reporter
helm repo update
helm install policy-reporter policy-reporter/policy-reporter -n policy-reporter --create-namespace --set ui.enabled=true
```

Wait until the Pods in the `policy-reporter` namespace are ready, then forward the user interface Service to your machine. List the Services first, because the Service name depends on the chart version:

```sh
kubectl get svc -n policy-reporter
kubectl port-forward -n policy-reporter svc/policy-reporter-ui 8082:8080
```

Open `http://localhost:8082` in a browser. The dashboard groups findings by namespace, policy and severity, which are the same fields you grouped by in the triage workflow.

## Metrics and notifications

Policy Reporter exports report data as Prometheus metrics, so a dashboard or an alert rule can use report counts without a custom script. It can also send a message to a notification target when a result is new. In both cases, you choose a minimum severity or a list of result values, so a channel does not fill with advisory findings.

These are separate from the Kyverno metrics endpoint. Kyverno metrics describe the work Kyverno does, such as rules evaluated. Policy Reporter metrics describe the content of reports, such as findings per policy.

## Kyverno Reports Server

A cluster with a very large number of reports can load the Kubernetes API server and etcd, since every report is a stored object. The Kyverno Reports Server is a separate component that serves the same report API from its own database instead of etcd. It is optional, and the reports pipeline from the earlier parts stays the same. Check the current Kyverno documentation before you plan one, because it is newer than the core reporting feature.

## Limits that every consumer shares

Every tool sees only what the reports hold. The following facts apply to all of them.

- `warn` means an advisory policy, so a consumer that alerts on `fail` ignores it.
- `skip` includes resources exempted by a `PolicyException`, so a count of `skip` can hide a growing list of exemptions.
- A resource blocked by an `Enforce` policy leaves no report.
- A report is only as fresh as the last scan or admission event.

> [!TIP]
> **Try it**
>
> Install Policy Reporter in the playground, open the dashboard, and find the failing result for `violator-pod`. Then confirm the same result with `kubectl get polr -n platform-ns -o yaml`. Both show one result, because both read one report.

You can now describe what a report consumer adds, install one, and explain which questions it cannot answer.

## Common pitfalls

> [!WARNING]
> - Trusting a dashboard that shows green while policies run in `Enforce` mode. Blocked requests never create reports, so the dashboard has nothing to show for them.
> - Sending every result to a notification channel. Filter by severity and result value, or the channel becomes noise.
> - Treating Policy Reporter as part of Kyverno. It is a separate project with its own releases and its own configuration.
