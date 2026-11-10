#!/usr/bin/env bash
#
# Removes what uninstalling the package leaves behind on purpose: the OpenTelemetry resources, their CustomResourceDefinitions,
# and the namespace. The finalizers are removed first, since the operator isn't running anymore to handle them.
#
#   ../cleanup.sh <operator-namespace>

set -eo pipefail

crds=$(kubectl get crds -o name | grep '\.opentelemetry\.io$' | cut -d/ -f2)

for crd in $crds; do
  kubectl get "$crd" -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' |
    while read -r namespace name; do
      kubectl patch "$crd" "$name" -n "$namespace" --type=merge -p '{"metadata":{"finalizers":null}}'
    done
done
# shellcheck disable=SC2086
kubectl delete crds $crds --wait
kubectl delete namespace "$1" --wait
