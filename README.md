# OpenTelemetry Operator

![Test Workflow](https://github.com/kadras-io/package-for-opentelemetry-operator/actions/workflows/test.yml/badge.svg)
![Release Workflow](https://github.com/kadras-io/package-for-opentelemetry-operator/actions/workflows/release.yml/badge.svg)
[![The SLSA Level 3 badge](https://slsa.dev/images/gh-badge-level3.svg)](https://slsa.dev/spec/v1.0/levels)
[![The Apache 2.0 license badge](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Follow us on Bluesky](https://img.shields.io/static/v1?label=Bluesky&message=Follow&color=1DA1F2)](https://bsky.app/profile/kadras.bsky.social)

A Carvel package for [OpenTelemetry Operator](https://opentelemetry.io/docs/platforms/kubernetes/operator), which manages OpenTelemetry Collectors and the auto-instrumentation of workloads using OpenTelemetry instrumentation libraries.

## ✨&nbsp; What's Included

* **OpenTelemetry operator**. The OpenTelemetry Operator and its admission webhooks, configured via the package values, with optional standby replicas for high availability.
* **Auto-instrumentation**. The languages that can be instrumented are configurable, with Go disabled by default since it requires privileged containers.
* **Safe lifecycle**. Uninstalling the package keeps the OpenTelemetry CRDs, so the collectors and the instrumentation settings survive it.
* **Observability**. Structured JSON logs, and metrics annotated for Prometheus scraping.
* **Security**. The operator complies with the `restricted` [Pod Security Standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/), enforced on its namespace. Private registries are supported for the operator image.

## 🚀&nbsp; Getting Started

### Prerequisites

* Kubernetes 1.35+
* Carvel [`kctrl`](https://carvel.dev/kapp-controller/docs/latest/install/#installing-kapp-controller-cli-kctrl) CLI.
* Carvel [kapp-controller](https://carvel.dev/kapp-controller) deployed in your Kubernetes cluster. You can install it with Carvel [`kapp`](https://carvel.dev/kapp/docs/latest/install) (recommended choice) or `kubectl`.

```shell
kapp deploy -a kapp-controller -y \
  -f https://github.com/carvel-dev/kapp-controller/releases/latest/download/release.yml
```

### Dependencies

The OpenTelemetry Operator requires the following packages, available to install from the [Kadras package repository](https://github.com/kadras-io/kadras-packages):

* [cert-manager](https://github.com/kadras-io/package-for-cert-manager), to issue the certificate of the admission webhooks.

To authenticate with private registries, install [secretgen-controller](https://github.com/kadras-io/package-for-secretgen-controller) too.

### Installation

Add the Kadras [package repository](https://github.com/kadras-io/kadras-packages) to your Kubernetes cluster:

```shell
kctrl package repository add -r kadras-packages \
  --url ghcr.io/kadras-io/kadras-packages \
  -n kadras-system --create-namespace
```

<details><summary>Installation without package repository</summary>
The recommended way of installing the OpenTelemetry Operator package is via the Kadras <a href="https://github.com/kadras-io/kadras-packages">package repository</a>. If you prefer not using the repository, you can add the package definition directly using <a href="https://carvel.dev/kapp/docs/latest/install"><code>kapp</code></a> or <code>kubectl</code>.

```shell
kubectl create namespace kadras-system
kapp deploy -a opentelemetry-operator-package -n kadras-system -y \
  -f https://github.com/kadras-io/package-for-opentelemetry-operator/releases/latest/download/metadata.yml \
  -f https://github.com/kadras-io/package-for-opentelemetry-operator/releases/latest/download/package.yml
```
</details>

Install the OpenTelemetry Operator package:

```shell
kctrl package install -i opentelemetry-operator \
  -p opentelemetry-operator.packages.kadras.io \
  -v ${VERSION} \
  -n kadras-system
```

> **Note**
> You can find the `${VERSION}` value by retrieving the list of package versions available in the Kadras package repository installed on your cluster.
> 
> ```shell
> kctrl package available list -p opentelemetry-operator.packages.kadras.io -n kadras-system
> ```

Verify the installed packages and their status:

```shell
kctrl package installed list -n kadras-system
```

### Try It Out

Create a collector receiving telemetry via OTLP and printing it to its logs, and the Java auto-instrumentation exporting to it:

```shell
kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel
  namespace: default
spec:
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    exporters:
      debug: {}
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [debug]
---
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: java
  namespace: default
spec:
  exporter:
    endpoint: http://otel-collector:4318
EOF
```

Annotate the Pods of a Java application with `instrumentation.opentelemetry.io/inject-java: "true"`, then follow the traces in the collector logs:

```shell
kubectl logs -n default deployment/otel-collector -f
```

See [getting started](https://github.com/open-telemetry/opentelemetry-operator/tree/main/docs/getting-started) and [auto-instrumentation](https://github.com/open-telemetry/opentelemetry-operator/tree/main/docs/auto-instrumentation).

## 📙&nbsp; Documentation

Documentation, tutorials and examples for this package are available in the [docs](docs) folder.
For documentation specific to the OpenTelemetry Operator, check out [opentelemetry.io](https://opentelemetry.io/docs/platforms/kubernetes/operator/) and the [operator docs](https://github.com/open-telemetry/opentelemetry-operator/tree/main/docs).

Features:

* [High availability](docs/high-availability.md)
* [Observability](docs/observability.md)
* [Security](docs/security.md)

Operations:

* [Configuration and ytt overlays](docs/configuration.md)
* [Upgrading and uninstalling](docs/upgrade.md)
* [Verifying the release](docs/verify-release.md)

## 🎯&nbsp; Configuration

The OpenTelemetry Operator package can be customized via a `values.yml` file.

```yaml
replicas: 2
auto_instrumentation:
  dotnet: false
  nginx: false
config:
  collector-image: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.162.0
```

Reference the `values.yml` file from the `kctrl` command when installing or upgrading the package.

```shell
kctrl package install -i opentelemetry-operator \
  -p opentelemetry-operator.packages.kadras.io \
  -v ${VERSION} \
  -n kadras-system \
  --values-file values.yml
```

The operator configuration and flags can be customized beyond the values, as well as any resource via ytt overlays. See [configuration.md](docs/configuration.md).

### Values

The OpenTelemetry Operator package has the following configurable properties.

<details><summary>Configurable properties</summary>

<!-- values-table:start -->

| Config | Default | Description |
|--------|---------|-------------|
| `namespace` | `"opentelemetry-operator-system"` | The namespace in which to deploy the OpenTelemetry Operator. |
| `replicas` | `1` | The number of operator replicas. Additional replicas are standby via leader election, and all of them serve the admission webhooks. With more than 1 replica, a PodDisruptionBudget is created. |
| `args` | `{}` | Container flags, merged on top of the ones computed by the package. Set a flag to null to remove it. See https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/reference/configuration.md. |
| `config` | `{}` | Operator configuration file, merged on top of the one computed by the package. Set an option to null to remove it. See https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/reference/configuration.md. |
| `auto_instrumentation.apache_httpd` | `true` | Whether to support Apache HTTPD auto-instrumentation. |
| `auto_instrumentation.dotnet` | `true` | Whether to support .NET auto-instrumentation. |
| `auto_instrumentation.go` | `false` | Whether to support Go auto-instrumentation. It injects a privileged sidecar container, which the `baseline` and `restricted` Pod Security Standards reject. |
| `auto_instrumentation.java` | `true` | Whether to support Java auto-instrumentation. |
| `auto_instrumentation.nginx` | `true` | Whether to support Nginx auto-instrumentation. |
| `auto_instrumentation.nodejs` | `true` | Whether to support Node.js auto-instrumentation. |
| `auto_instrumentation.php` | `false` | Whether to support PHP auto-instrumentation. |
| `auto_instrumentation.python` | `true` | Whether to support Python auto-instrumentation. |
| `auto_instrumentation.ruby` | `false` | Whether to support Ruby auto-instrumentation. |
| `auto_instrumentation.multi_instrumentation` | `true` | Whether to support instrumenting the containers of the same Pod with different languages. |
| `observability.logging.level` | `"info"` | The log level of the operator. The logs are always in JSON format. |
| `observability.metrics.enabled` | `true` | Whether to annotate the operator Pods for Prometheus scraping. The operator exposes metrics on port 8443 (`/metrics`), over HTTPS and with authentication, unless configured otherwise via `config`. |

<!-- values-table:end -->

</details>

## 🛠️&nbsp; Development

The development environment is defined with [devenv](https://devenv.sh). Enter it with `devenv shell`, or automatically with [direnv](https://direnv.net) after running `direnv allow`. Run `task --list` to see all the available tasks.

```shell
# Run the unit tests, which render the package and check the result without a cluster.
task test:config

# Create a local kind cluster and run the integration tests on it.
task cluster:setup
task test:integration

# Deploy the package from the local sources to the current cluster.
task dev

# Update the table of configurable values in this README after changing the values schema.
task docs:values
```

The unit tests are described in [test/unit/README.md](test/unit/README.md).

## 🛡️&nbsp; Security

The security process for reporting vulnerabilities is described in [SECURITY.md](SECURITY.md).

## 🖊️&nbsp; License

This project is licensed under the **Apache License 2.0**. See [LICENSE](LICENSE) for more information.
