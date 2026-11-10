# High Availability

## Operator

The package runs 1 replica of the operator. The collectors keep running and receiving telemetry while the operator is unavailable, and the operator reconciles them again when it's back. However, the operator also serves the admission webhooks:

* The webhooks validating and defaulting the OpenTelemetry resources reject their changes while no replica is available.
* The webhook injecting auto-instrumentation and sidecar collectors in the Pods is ignored while no replica is available: the Pods created meanwhile, for example during a node drain or a rollout, start without instrumentation, and aren't instrumented until they're recreated.

The operator runs with leader election: additional replicas are standby, and all of them serve the admission webhooks. With more than one replica, they're spread across nodes when possible, and a PodDisruptionBudget evicts one at a time during node drains. Run at least 2 replicas when the Pods rely on auto-instrumentation.

```yaml
replicas: 2
```

See [webhook high availability](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/rfcs/webhook-high-availability.md). To keep the operator on dedicated nodes, see [configuration.md](configuration.md#node-placement).

## Collectors

The high availability of the collectors is configured in each `OpenTelemetryCollector`, with the deployment mode, the number of replicas or the autoscaler, and the PodDisruptionBudget, which the operator creates by default with `maxUnavailable: 1`. See [deployment modes](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/collector/deployment-modes.md).

## Operator upgrades

After an operator upgrade, the collectors that don't set `spec.image` are rolled out with the collector version the operator was released with. See [upgrade.md](upgrade.md).
