#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source all libraries
source "$BASE_DIR/lib/colors.sh"
source "$BASE_DIR/lib/atomic_helm.sh"

DOMAIN="${DOMAIN:-osh.cloud.dev}"
INGRESS_CLASS="${INGRESS_CLASS:-nginx}"

NIC="${NIC:-enp8s0}"

OPENSTACK_RELEASE="${OPENSTACK_RELEASE:-2026.1}"
OS_DISTRO="${OS_DISTRO:-ubuntu_noble}"
FEATURES="${FEATURES:-${OPENSTACK_RELEASE} ${OS_DISTRO}}"
OSH_PWD="${OSH_PWD:-$(eval echo "~${SUDO_USER:-$USER}")/osh}"
OVERRIDES_DIR="${OVERRIDES_DIR:-${OSH_PWD}/overrides}"
K3S_OVERRIDES_DIR="${K3S_OVERRIDES_DIR:-${OSH_PWD}/overrides_k3s}"
OVERRIDES_URL=https://opendev.org/openstack/openstack-helm/raw/branch/master/values_overrides

HELM_OSH_REPO_URL="https://tarballs.opendev.org/openstack/openstack-helm"

INFRA=0
CORE=0
LIBVIRT=0
COMPUTE=0
CINDER=0
HEAT=0
SKYLINE=0
WITH_STEPCA=0
ALL=0
UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --infra) INFRA=1 ;;
    --core) CORE=1 ;;
    --libvirt) LIBVIRT=1 ;;
    --compute) COMPUTE=1 ;;
    --cinder) CINDER=1 ;;
    --heat) HEAT=1 ;;
    --skyline) SKYLINE=1 ;;
    --with-stepca) WITH_STEPCA=1 ;;
    --all) ALL=1 ;;
    --uninstall) UNINSTALL=1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }; }

# Ensure kubeconfig for k3s
if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

require_cmd kubectl

uninstall_all() {
  info "Uninstalling OSH…"
  set +e

  for chart in skyline horizon nova heat cinder glance keystone rabbitmq mariadb memcached openvswitch; do
    output=$(helm -n openstack uninstall "$chart" 2>&1)
    if [[ $? -ne 0 ]]; then
        err "Failed to uninstall $chart: $output"
    else
        ok "Uninstalled $chart"
    fi

    pvcs=$(kubectl -n openstack get pvc -l app.kubernetes.io/instance="$chart" -o name 2>/dev/null)
    if [[ -n "$pvcs" ]]; then
        info "Removing PVCs related to $chart"
        kubectl -n openstack delete $pvcs
        ok "Deleted PVCs for $chart: $pvcs"
    fi

    secrets=$(kubectl -n openstack get secret -l app.kubernetes.io/instance="$chart" -o name 2>/dev/null)
    if [[ -n "$secrets" ]]; then
        info "Removing Secrets related to $chart"
        kubectl -n openstack delete $secrets
        ok "Deleted Secrets for $chart: $secrets"
    fi

    # --- Delete related ConfigMaps ---
    configmaps=$(kubectl -n openstack get configmap -l app.kubernetes.io/instance="$chart" -o name 2>/dev/null)
    if [[ -n "$configmaps" ]]; then
        info "Removing ConfigMaps related to $chart"
        kubectl -n openstack delete $configmaps
        ok "Deleted ConfigMaps for $chart: $configmaps"
    fi

    jobs=$(kubectl -n openstack get jobs -o name 2>/dev/null)
    if [[ -n "$jobs" ]]; then
        info "Removing Jobs related to $chart"
        kubectl -n openstack delete $jobs
        ok "Deleted ConfigMaps for $chart: $jobs"
    fi
  done

  kubectl -n openstack delete configmap mariadb-mariadb-state 2>/dev/null

  ok "Uninstall complete."
  exit 0
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  command -v kubectl >/dev/null 2>&1 || true
  uninstall_all
fi

info "Installing OSH..."

if [[ "$INFRA" -eq 1 ]]; then

    # --- Deploying OSH-Infra -----------------------------------
    info "Deploying OSH Infra..."

for chart in rabbitmq mariadb memcached openvswitch libvirt keystone heat glance cinder trove placement nova neutron horizon; do
    helm osh get-values-overrides -d -u ${OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done

helm upgrade --install rabbitmq openstack-helm/rabbitmq \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    --timeout=600s \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c rabbitmq ${FEATURES})

helm osh wait-for-pods openstack

ok "OSH installation complete"
