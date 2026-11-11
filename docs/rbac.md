# Access to the Resources

The package extends the Kubernetes [default roles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) with the OpenTelemetry Operator resources, via [aggregation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#aggregated-clusterroles). The users bound to `admin`, `edit`, or `view` in a namespace get the following permissions on the resources in that namespace.

| Resources | `admin`, `edit` | `view` |
|-----------|-----------------|--------|
| Instrumentation, OpenTelemetryCollector, TargetAllocator, OpAMPBridge | Read and write | Read |

The OpenTelemetry collectors and the auto-instrumentation of the applications of the namespace.

The permissions are granted by the `opentelemetry-operator-edit` and `opentelemetry-operator-view` ClusterRoles.
