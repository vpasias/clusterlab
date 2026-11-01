#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source all libraries
source "$BASE_DIR/lib/colors.sh"
source "$BASE_DIR/lib/atomic_helm.sh"

OSH_DOMAIN="${OSH_DOMAIN:-osh.cloud.dev}"
MGMT_DOMAIN="${MGMT_DOMAIN:-int.cloud.dev}"

OSH_INGRESS_CLASS="${OSH_INGRESS_CLASS:-nginx}"
MGMT_INGRESS_CLASS="${MGMT_INGRESS_CLASS:-traefik}"

OSH_PWD="${OSH_PWD:-$(eval echo "~${SUDO_USER:-$USER}")/osh}"
OVERRIDES_DIR="${OVERRIDES_DIR:-${OSH_PWD}/overrides}"
K3S_OVERRIDES_DIR="${K3S_OVERRIDES_DIR:-${OSH_PWD}/overrides_k3s}"

ROOK_NS="${ROOK_NS:-rook-ceph}"
ROOK_RELEASE="${ROOK_RELEASE:-v1.17.7}"
ROOK_REPO_URL="${ROOK_REPO_URL:-https://charts.rook.io/release}"

CEPH_NS="${CEPH_NS:-ceph}"
CEPH_IMAGE="${CEPH_IMAGE:-quay.io/ceph/ceph:v19.2.3}"

OPENSTACK_NS="${OPENSTACK_NS:-openstack}"
HELM_OSH_REPO_URL="https://tarballs.opendev.org/openstack/openstack-helm"
KITE_REPO_URL="${KITE_REPO_URL:-https://github.com/kite-org/kite}"
NGINX_REPO_URL="${NGINX_REPO_URL:-https://kubernetes.github.io/ingress-nginx}"

require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }; }

# Ensure kubeconfig for k3s
if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

require_cmd kubectl

info "Installing OSH dependencies"

# --- Namespaces --------------------------------------------------------------
info "Creating namespaces"
info "Creating namespaces"
kubectl create namespace "${CEPH_NS}" 2>/dev/null || true
kubectl create namespace "${ROOK_NS}" 2>/dev/null || true
kubectl create namespace "${OPENSTACK_NS}" 2>/dev/null || true
kubectl create namespace kite 2>/dev/null || true
kubectl create namespace kubevpn 2>/dev/null || true

# --- Clone OSH repos and download override -----------------------------------
info "Cloning or updating OSH repos"
mkdir -p $OSH_PWD
cd $OSH_PWD

if [[ ! -d openstack-helm ]]; then
  git clone https://opendev.org/openstack/openstack-helm.git
  ok "Cloned opnestack-helm.git"
else (cd openstack-helm && git pull --ff-only || true); fi

if [[ ! -d openstack-helm-infra ]]; then
  git clone https://opendev.org/openstack/openstack-helm-infra.git 
  ok "Cloned opnestack-helm-infra.git"
else (cd openstack-helm-infra && git pull --ff-only || true); fi

sudo chown -R $SUDO_USER:$SUDO_USER $OSH_PWD

mkdir -p $OVERRIDES_DIR
sudo chown -R $SUDO_USER:$SUDO_USER $OVERRIDES_DIR

mkdir -p $K3S_OVERRIDES_DIR
sudo chown -R $SUDO_USER:$SUDO_USER $K3S_OVERRIDES_DIR

ok "Installed OSH dependencies"

# --- Overwrite node labels and taints -----------------------------------
kubectl label --overwrite nodes --all openstack-control-plane=enabled >/dev/null 2>&1 || true
kubectl label --overwrite nodes --all openstack-compute-node=enabled  >/dev/null 2>&1 || true
kubectl label --overwrite nodes --all openvswitch=enabled            >/dev/null 2>&1 || true
kubectl label --overwrite nodes --all linuxbridge=enabled            >/dev/null 2>&1 || true
 
kubectl taint nodes -l 'node-role.kubernetes.io/control-plane' node-role.kubernetes.io/control-plane- >/dev/null 2>&1 || true

ok "Overwrite node labels and taints"

ok "Kubernetes nodes:"
kubectl get nodes -o wide

# --- Add Helm repos & plugins -----------------------------------
info "Adding Helms Repos"
helm repo add openstack-helm "$HELM_OSH_REPO_URL" >/dev/null 2>&1 || true
helm repo add rook-release "${ROOK_REPO_URL}" >/dev/null 2>&1 || true
helm repo add kite "${KITE_REPO_URL}" >/dev/null 2>&1 || true
helm repo add ingress-nginx "${NGINX_REPO_URL}" >/dev/null 2>&1 || true

helm repo update >/dev/null 2>&1 || true

helm cache clean 2>/dev/null || true

# --- Install OSH ceph-adapter-rook -----------------------------------
helm_safe_install_atomic ceph-adapter-rook ceph-adapter-rook "${OPENSTACK_NS}" "${HELM_OSH_REPO_URL}" \
    --wait --timeout 30m

helm osh wait-for-pods ${OPENSTACK_NS}

# --- Install MetalLB -----------------------------------
tee > /tmp/metallb_system_namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: metallb-system
EOF
kubectl apply -f /tmp/metallb_system_namespace.yaml

helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system

tee > /tmp/metallb_ipaddresspool.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: public
    namespace: metallb-system
spec:
    addresses:
    - "172.19.123.200–172.19.123.250"
EOF

kubectl apply -f /tmp/metallb_ipaddresspool.yaml

tee > /tmp/metallb_l2advertisement.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: public
    namespace: metallb-system
spec:
    ipAddressPools:
    - public
EOF

kubectl apply -f /tmp/metallb_l2advertisement.yaml

# --- Install Nginx Ingress Controller for Openstack -----------------------------------
info "Install Nginx Ingress Controller for Openstack"

helm_safe_install_atomic ingress-nginx ingress-nginx openstack "${NGINX_REPO_URL}" \
    --version="4.8.3" \
    --set controller.kind=Deployment \
    --set controller.admissionWebhooks.enabled="false" \
    --set controller.scope.enabled="true" \
    --set controller.service.enabled="false" \
    --set controller.ingressClassResource.name=${OSH_INGRESS_CLASS} \
    --set controller.ingressClassResource.controllerValue="k8s.io/ingress-nginx" \
    --set controller.ingressClassResource.default="false" \
    --set controller.ingressClass=${OSH_INGRESS_CLASS} \
    --set controller.labels.app=ingress-api \
    --wait --timeout 10m >/dev/null 2>&1 || true

helm osh wait-for-pods openstack

cat > "$K3S_OVERRIDES_DIR/openstack_endpoint_service.yaml" <<EOF
---
kind: Service
apiVersion: v1
metadata:
  name: public-openstack
  namespace: openstack
  annotations:
    metallb.universe.tf/loadBalancerIPs: "172.19.123.250"
spec:
  externalTrafficPolicy: Cluster
  type: LoadBalancer
  selector:
    app: ingress-api
  ports:
    - name: http
      port: 80
    - name: https
      port: 443
EOF

kubectl apply -f "$K3S_OVERRIDES_DIR/openstack_endpoint_service.yaml" >/dev/null 2>&1 || true
ok "Installed public-openstack (app: ingress-api) service"
warn "You need to manually add the following external IP addresses to your DNS"
kubectl get svc public-openstack -n openstack

ok "Installed OSH dependencies"

# --- Kite deployment  ---------------------------------------
  info "Deploying Kite…"

  cat > $K3S_OVERRIDES_DIR/kite.yaml <<EOF
  anonymousUserEnabled: true
  ingress:
    enabled: true
    className: ${MGMT_INGRESS_CLASS}
    hosts:
      - host: kite.${MGMT_DOMAIN}
        paths:
          - path: /
            pathType: ImplementationSpecific
EOF

helm_safe_install_atomic kite kite kite "${KITE_REPO_URL}" \
    -f $K3S_OVERRIDES_DIR/kite.yaml \
    --wait --timeout 10m

  helm osh wait-for-pods kite

ok "Installed OSH dependencies"
