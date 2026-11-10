# Configuration

The package values cover the decisions most installations need to make: the operator namespace and replicas, the languages supported by auto-instrumentation, and observability. Everything else can still be customized in three ways.

## Operator configuration

The operator reads its configuration from a file, at startup, then applies the environment variables and the flags on top. The package computes the file from the values, then merges `config` on top, so its options take precedence. An option set to `null` is removed. The file is stored in the `opentelemetry-operator-config` ConfigMap in the operator namespace, and mounted in the operator. When the configuration changes, the operator is rolled out to load it.

```yaml
config:
  collector-image: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.162.0
  feature-gates: operator.networkpolicy
  labels-filter:
    - app.kubernetes.io/managed-by
```

The available options are listed in the [configuration reference](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/reference/configuration.md), under "YAML key". The names of the keys differ from the ones of the flags in some cases, like `enable-node-js-auto-instrumentation` and `--enable-nodejs-instrumentation`. The ones computed by the package are:

| Option | Value |
|--------|-------|
| `enable-leader-election` | `true`, see [high-availability.md](high-availability.md) |
| `metrics-addr` | `:8443`, see [observability.md](observability.md#metrics) |
| `metrics-secure` | `true`, see [observability.md](observability.md#metrics) |
| `enable-multi-instrumentation` | `auto_instrumentation.multi_instrumentation` |
| `enable-<language>-auto-instrumentation` | `auto_instrumentation.<language>` |

Upstream, the operator Deployment sets some of these options via environment variables, which would override the configuration file. The package moves them to the file, and keeps only the `NAMESPACE` and `SERVICE_ACCOUNT_NAME` environment variables.

### Auto-instrumentation

The operator injects the OpenTelemetry instrumentation libraries in the Pods annotated with `instrumentation.opentelemetry.io/inject-<language>`, as configured by an `Instrumentation` resource. Each language can be enabled or disabled. The Pods annotated for a disabled language are created without instrumentation.

```yaml
auto_instrumentation:
  java: true
  nodejs: true
  python: true
  dotnet: false
  apache_httpd: false
  nginx: false
```

Go auto-instrumentation is disabled by default, since it injects a privileged sidecar container (see [security.md](security.md#auto-instrumentation)). The containers of the same Pod can be instrumented with different languages, unless `multi_instrumentation` is disabled. See [auto-instrumentation](https://github.com/open-telemetry/opentelemetry-operator/tree/main/docs/auto-instrumentation).

The images of the instrumentation libraries and of the collectors default to the ones the operator was released with. They can be changed for all the resources via the configuration (`collector-image`, `auto-instrumentation-java-image`, ...), or in each resource.

## Container flags

The operator is configured via container flags too, applied on top of the configuration file. The package computes the path of the configuration file and the log level and format, and merges them into the upstream flags, then merges `args` on top, so its flags take precedence. The flags are written without the leading dashes, and a flag set to `null` is removed.

```yaml
args:
  watch-namespace: observability,apps
  zap-level-key: severity
```

An unknown flag prevents the operator from starting. Check the [configuration reference](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/reference/configuration.md) of the OpenTelemetry Operator version you install before adding one. A change rolls out the operator. Prefer the configuration file for the options available in both.

## ytt overlays

Any Kubernetes resource of the package can be customized with a [ytt overlay](https://carvel.dev/ytt/docs/latest/ytt-overlays/). Store it in a Secret and reference it from the PackageInstall via the `ext.packaging.carvel.dev/ytt-paths-from-secret-name.0` annotation.

```shell
kubectl create secret generic opentelemetry-operator-overlays -n kadras-system --from-file=overlays.yml
kubectl annotate packageinstall opentelemetry-operator -n kadras-system \
  ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=opentelemetry-operator-overlays
```

The operator runs in the `opentelemetry-operator-controller-manager` Deployment, in a container named `manager`.

### Resources

The upstream manifest requests 100m CPU and 64Mi memory, without limits. The memory used by the operator grows with the number of Pods, Deployments, and other resources in the cluster, which it watches.

```yaml
#@ load("@ytt:overlay", "overlay")

#@overlay/match by=overlay.subset({"kind": "Deployment", "metadata": {"name": "opentelemetry-operator-controller-manager"}})
---
spec:
  template:
    spec:
      containers:
        #@overlay/match by="name"
        - name: manager
          resources:
            limits:
              memory: 512Mi
            requests:
              cpu: 100m
              memory: 256Mi
```

### Node placement

Keep the operator on dedicated nodes, so that it's not evicted together with the workloads it instruments.

```yaml
#@ load("@ytt:overlay", "overlay")

#@overlay/match by=overlay.subset({"kind": "Deployment", "metadata": {"name": "opentelemetry-operator-controller-manager"}})
---
spec:
  template:
    spec:
      #@overlay/match missing_ok=True
      nodeSelector:
        node-restriction.kubernetes.io/reserved-for: platform
      #@overlay/match missing_ok=True
      tolerations:
        - key: node-restriction.kubernetes.io/reserved-for
          operator: Equal
          value: platform
          effect: NoExecute
```
