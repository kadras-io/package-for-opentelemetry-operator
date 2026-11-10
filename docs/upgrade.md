# Upgrading

Read the [release notes](https://github.com/open-telemetry/opentelemetry-operator/releases) of each OpenTelemetry Operator version before upgrading, since some versions change the collector configuration or the API of the OpenTelemetry resources.

```shell
kctrl package installed update -i opentelemetry-operator -v ${VERSION} -n kadras-system
```

The OpenTelemetry Operator follows the version of the OpenTelemetry Collector, and runs the collectors that don't set `spec.image` with the collector version it was released with: after an upgrade, they're all rolled out with the new version. The operator also migrates the `OpenTelemetryCollector` resources to the new collector version, rewriting their configuration when the collector format changed.

To skip the migration of a collector, set `spec.upgradeStrategy: none` in its resource. To manage its version yourself, set `spec.image` too, and keep it close to the version of the operator. See [upgrades](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/getting-started/upgrading.md) and [compatibility](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/getting-started/compatibility.md).

The instrumentation libraries are upgraded too, in the `Instrumentation` resources whose images were defaulted by the operator, and injected in the Pods created afterwards. The running Pods keep the previous version until they're restarted.

## Uninstalling

Deleting the OpenTelemetry CRDs would delete all the `OpenTelemetryCollector`, `Instrumentation`, `TargetAllocator`, and `OpAMPBridge` resources, and with them the collectors they own. Uninstalling the package doesn't delete them: it keeps the CRDs and the operator namespace, and only deletes the operator and its webhooks. The collectors keep running without the operator, and the Pods created meanwhile aren't instrumented. Installing the package again resumes the reconciliation.

To remove everything, delete the OpenTelemetry resources before uninstalling the package, while the operator still runs, then delete the CRDs and the namespace.

```shell
kubectl delete opentelemetrycollectors.opentelemetry.io,instrumentations.opentelemetry.io --all -A
kctrl package installed delete -i opentelemetry-operator -n kadras-system
kubectl get crds -o name | grep '\.opentelemetry\.io$' | xargs kubectl delete
kubectl delete namespace opentelemetry-operator-system
```
