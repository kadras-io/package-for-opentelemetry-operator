# Security

See the [collector security documentation](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/collector/security.md) for the security model of the collectors managed by the operator.

## Pod Security Standards

The operator complies with the `restricted` [Pod Security Standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/), enforced on the package namespace. The upstream manifest doesn't set the security context of the operator, so the package does: it runs as a non-root user, with a read-only root filesystem, without privilege escalation and capabilities, and with the default seccomp profile.

The collectors run in the namespaces of their `OpenTelemetryCollector`. Their security context, volumes, and host namespaces are set in the resource and passed to the Pods as written, so Pod Security Admission on those namespaces, not the operator, is the boundary.

## Permissions

The operator runs with the `opentelemetry-operator-controller-manager` ServiceAccount, bound to the `opentelemetry-operator-manager-role` ClusterRole, since it manages collectors in all namespaces: it creates Deployments, DaemonSets, StatefulSets, Services, ConfigMaps, and the other resources of the collectors, and reads the Pods, Secrets, and Namespaces. To restrict it to some namespaces, set the `watch-namespace` flag (see [configuration.md](configuration.md#container-flags)).

An `OpenTelemetryCollector` can set host paths, host networking, and privileged containers, which the operator passes to the collector Pods: in `daemonset` mode, that's root access to every node. Grant write access to the `OpenTelemetryCollector` resources only to trusted users, as you would for DaemonSets, or restrict the fields with a ValidatingAdmissionPolicy. See [restricting the fields](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/collector/security.md#restricting-the-fields).

## Auto-instrumentation

The operator mutates the Pods in all namespaces, via its admission webhook, to inject the instrumentation libraries and the sidecar collectors requested via annotations. The libraries are copied by init containers, from images defined in the `Instrumentation` resources. Anyone who can create an `Instrumentation` resource can make the annotated Pods of its namespace run any image.

Go auto-instrumentation injects a privileged sidecar container, which the `baseline` and `restricted` Pod Security Standards reject. That's why it's disabled by default (see [configuration.md](configuration.md#auto-instrumentation)).

## Private registries

The `canonical-registry-credentials` Secret in the package namespace holds the credentials to pull the operator image from a private registry. It's populated by [secretgen-controller](https://github.com/carvel-dev/secretgen-controller) from a Secret exported to the package namespace.

The collectors, the target allocators, and the instrumentation libraries aren't part of the package. Their images are pulled in the namespaces of the workloads: reference them from the OpenTelemetry resources, or for all the resources via the configuration (`collector-image`, `auto-instrumentation-java-image`, ...). To pull them from a private registry, add the credentials to the ServiceAccount of the collector (`spec.serviceAccount`) and of the instrumented Pods. See [using imagePullSecrets](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/collector/image-pull-secrets.md).

## Admission webhooks

The operator serves the admission webhooks that default and validate the OpenTelemetry resources, that inject auto-instrumentation and sidecars in the Pods, and that convert the `OpenTelemetryCollector` resources between API versions, on port 9443. Their certificate is issued by [cert-manager](https://cert-manager.io) via a self-signed Issuer, in the `opentelemetry-operator-controller-manager-service-cert` Secret, and cert-manager injects its CA into the webhook configurations and the CRDs. The package keeps the injected CA when it's reconciled.

On some managed Kubernetes services, like private GKE clusters, a firewall blocks the traffic from the control plane to the nodes, except for a few ports. If creating a resource fails with `failed calling webhook`, open port 9443 in the firewall.

## Network policies

The package doesn't include network policies. The operator can create one for itself, with the `operator.networkpolicy` feature gate (see [configuration.md](configuration.md#operator-configuration)). If you add your own, allow:

* the inbound traffic from the Kubernetes API server to the operator on port 9443 (admission webhooks), and from Prometheus on port 8443 (metrics);
* the outbound traffic from the operator to the Kubernetes API server.

With the `operand.networkpolicy` feature gate, the operator creates network policies for the collectors and target allocators too.

## Image verification

The OpenTelemetry Operator images are signed with [Cosign keyless signatures](https://docs.sigstore.dev/cosign/overview) by the release workflow on GitHub Actions.

```shell
cosign verify ghcr.io/open-telemetry/opentelemetry-operator/opentelemetry-operator:0.162.0 \
  --certificate-identity-regexp="^https://github.com/open-telemetry/opentelemetry-operator/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

The package itself is signed too. See [verify-release.md](verify-release.md).
