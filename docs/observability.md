# Observability

## Logs

The operator writes its logs in JSON format. The log level is one of `debug`, `info`, `error`.

```yaml
observability:
  logging:
    level: info
```

If your log ingestion system requires different names for the level, message, and timestamp fields, or a lowercase level, set them via the configuration (see [configuration.md](configuration.md#operator-configuration)).

```yaml
config:
  zap:
    level-key: severity
    time-key: time
    level-format: lowercase
```

To read the operator logs:

```shell
kubectl logs -n opentelemetry-operator-system deployment/opentelemetry-operator-controller-manager
```

The logs of the collectors are configured in each `OpenTelemetryCollector`, via `spec.config.service.telemetry.logs`.

## Metrics

The operator exposes metrics in the Prometheus format on port 8443 (`/metrics`), on the `https` container port, and via the `opentelemetry-operator-controller-manager-metrics-service` Service. The endpoint is served over HTTPS, with a self-signed certificate, and only to the clients authenticated with a ServiceAccount token and authorized via the `opentelemetry-operator-metrics-reader` ClusterRole.

The operator Pods are annotated for Prometheus scraping (`prometheus.io/scrape`, `prometheus.io/port`, `prometheus.io/path`, `prometheus.io/scheme`). To remove the annotations:

```yaml
observability:
  metrics:
    enabled: false
```

Bind the ClusterRole to the ServiceAccount of your Prometheus server or collector, and configure it to send its token and to skip the verification of the certificate.

```shell
kubectl create clusterrolebinding opentelemetry-operator-metrics-reader \
  --clusterrole=opentelemetry-operator-metrics-reader \
  --serviceaccount=<namespace>:<service-account>
```

To serve the metrics over plain HTTP, without authentication, disable `metrics-secure` in the configuration. The annotations follow the configured port and protocol.

```yaml
config:
  metrics-secure: false
```

If you use the Prometheus Operator, the operator can create a ServiceMonitor for itself, with the `create-service-monitor-operator-metrics` option. With `enable-cr-metrics`, it also exposes metrics about the OpenTelemetry resources.

The collectors expose their own metrics on port 8888, as configured in each `OpenTelemetryCollector` via `spec.config.service.telemetry.metrics`. With `spec.observability.metrics.enableMetrics`, the operator creates a ServiceMonitor or PodMonitor for them when the Prometheus Operator is installed.
