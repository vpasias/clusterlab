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

    cat > ${K3S_OVERRIDES_DIR}/rabbitmq.yaml <<-EOF
    images:
      tags:
          rabbitmq_init:  quay.io/airshipit/heat:${OPENSTACK_RELEASE}-${OS_DISTRO}
      pull_policy: IfNotPresent
EOF

      info "Ensuring OpenStack IngressClasses..."

  kubectl apply -f - >/dev/null 2>&1 <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: ingress-openstack
spec:
  controller: k8s.io/ingress-nginx
---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: ingress-cluster
spec:
  controller: k8s.io/ingress-nginx
EOF

    for chart in rabbitmq mariadb memcached openvswitch; do
        helm_safe_install_atomic $chart $chart openstack "${HELM_OSH_REPO_URL}" \
        --namespace=openstack \
        $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c $chart ${FEATURES} >/dev/null 2>&1 || true) \
            -f ${K3S_OVERRIDES_DIR}/rabbitmq.yaml \
            --wait --timeout 10m

        helm osh wait-for-pods openstack
    done

    # helm_safe_install_atomic libvirt libvirt openstack\
    #     --namespace=openstack \
    #     --set conf.ceph.enabled=true \
    #     $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c rabbitmq ${FEATURES} >/dev/null 2>&1 || true) \
    #         --wait --timeout 10m
fi

if [[ "$CORE" -eq 1 ]]; then

    info "Deploying OSH..."

    # --- Deploying Keystone -----------------------------------
    info "Deploying Keystone..."

    cat > ${K3S_OVERRIDES_DIR}/keystone.yaml <<-EOF
    endpoints:
      identity:
          host_fqdn_override:
            public:
              host: "keystone.${DOMAIN}"
EOF

    helm_safe_install_atomic keystone keystone openstack "${HELM_OSH_REPO_URL}" \
        $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c keystone ${FEATURES} >/dev/null 2>&1 || true) \
        -f ${K3S_OVERRIDES_DIR}/keystone.yaml \
        --wait --timeout 10m

    helm osh wait-for-pods openstack

    # --- Deploying Horizon -----------------------------------
    info "Deploying Horizon..."

    cat > ${K3S_OVERRIDES_DIR}/horizon.yaml <<-EOF
endpoints:
  dashboard:
    host_fqdn_override:
      public:
        host: "horizon.${DOMAIN}"
    scheme:
      default: http
      public: https
network:
  dashboard:
    ingress:
      annotations:
        # kubernetes.io/ingress.class: "nginx"
        nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
        nginx.ingress.kubernetes.io/affinity: "cookie"
        nginx.ingress.kubernetes.io/session-cookie-name: "route"
        nginx.ingress.kubernetes.io/session-cookie-hash: "sha1"
conf:
  horizon:
    local_settings:
      config:
        allowed_hosts:
          - "horizon.${DOMAIN}"
          - "*"
        csrf_trusted_origins:
          - "https://horizon.${DOMAIN}"
        csrf_cookie_secure: "False"
        session_cookie_secure: "False"
        session_cookie_httponly: "True"
        session_cookie_samesite: "Lax"
        secure_proxy_ssl_header: "HTTP_X_FORWARDED_PROTO"
        use_x_forwarded_host: "True"
EOF

    helm_safe_install_atomic horizon horizon openstack "${HELM_OSH_REPO_URL}" \
        $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c horizon ${FEATURES} >/dev/null 2>&1 || true) \
        -f ${K3S_OVERRIDES_DIR}/horizon.yaml \
        --wait --timeout 10m

    helm osh wait-for-pods openstack

    # --- Deploying Glance -----------------------------------
    info "Deploying Glance..."

    cat > ${K3S_OVERRIDES_DIR}/glance.yaml <<-EOF
    storage: pvc
    volume:
      class_name: general
      size: 10Gi
EOF

    helm_safe_install_atomic glance glance openstack "${HELM_OSH_REPO_URL}" \
        $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c glance ${FEATURES} >/dev/null 2>&1 || true) \
        -f ${K3S_OVERRIDES_DIR}/glance.yaml \
        --wait --timeout 10m

    helm osh wait-for-pods openstack

fi

if [[ "$CINDER" -eq 1 ]]; then

    # --- Deploying Cinder -----------------------------------
    info "Deploying Cinder..."
  
    helm_safe_install_atomic cinder cinder openstack "${HELM_OSH_REPO_URL}" \
        $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c cinder ${FEATURES} >/dev/null 2>&1 || true) \
        --wait --timeout 10m

    helm osh wait-for-pods openstack

fi

if [[ "$HEAT" -eq 1 ]]; then

    # --- Deploying Heat -----------------------------------
    info "Deploying Heat..."

    helm_safe_install_atomic heat heat openstack "${HELM_OSH_REPO_URL}" \
        $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c heat ${FEATURES} >/dev/null 2>&1 || true) \
        --wait --timeout 10m

    helm osh wait-for-pods openstack

fi

# if [[ "$SKYLINE" -eq 1 ]]; then

#   # --- Deploying Skyline -----------------------------------
#     info "Deploying Skyline..."

#     cat > ${K3S_OVERRIDES_DIR}/skyline.yaml <<-EOF
# endpoints:
#   skyline:
#     host_fqdn_override:
#       default: "skyline.${DOMAIN}"

# conf:
#   skyline:
#     openstack:
#       keystone_url: http://keystone-api.openstack.svc.cluster.local:5000/v3
#       default_region: RegionOne
#       interface_type: public
# EOF

#     helm_safe_install_atomic skyline skyline openstack "${HELM_OSH_REPO_URL}" \
#         $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c skyline ${FEATURES} >/dev/null 2>&1 || true) \
#         -f ${K3S_OVERRIDES_DIR}/skyline.yaml \
#         --wait --timeout 10m

#     # helm osh wait-for-pods openstack
# fi

if [[ "$SKYLINE" -eq 1 ]]; then

  info "Deploying Skyline..."

  cat > "${K3S_OVERRIDES_DIR}/skyline.yaml" <<EOF
endpoints:
  skyline:
    host_fqdn_override:
      default: "skyline.${DOMAIN}"

conf:
  skyline:
    openstack:
      keystone_url: http://keystone-api.openstack.svc.cluster.local:5000
      default_region: RegionOne
      interface_type: public

      # enforce_new_defaults: true
      # system_user_domain: Default
      # system_user_name: skyline
      # system_project_domain: Default
      # system_project: admin
      # system_reader_roles:
      #   - reader
      # system_admin_roles:
      #   - admin
EOF

  helm_safe_install_atomic skyline skyline openstack "${HELM_OSH_REPO_URL}" \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c skyline ${FEATURES}) \
    -f "${K3S_OVERRIDES_DIR}/skyline.yaml" \
    --wait --timeout 10m

fi

if [[ "$COMPUTE" -eq 1 ]]; then
    info "Deploying OSH Compute Kit (Placement, Nova, Neutron)..."

    helm_safe_install_nonblocking placement placement openstack "${HELM_OSH_REPO_URL}" \
      $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c placement ${FEATURES}) \
      --timeout 30m

    cat > ${K3S_OVERRIDES_DIR}/nova.yaml <<-EOF
endpoints:
  compute_novnc_proxy:
    host_fqdn_override:
      default: "novncproxy.${DOMAIN}"

conf:
  nova:
    DEFAULT:
      compute_driver: libvirt.LibvirtDriver
    vnc:
      novncproxy_base_url: "http://novncproxy.${DOMAIN}/vnc_auto.html"
    libvirt:
      virt_type: kvm
      connection_uri: "qemu+unix:///system?socket=/run/libvirt/libvirt-sock"
      live_migration_uri: "qemu+ssh://nova@%s/system"
      cpu_mode: host-passthrough
EOF

    helm_safe_install_nonblocking nova nova openstack "${HELM_OSH_REPO_URL}" \
      --set bootstrap.wait_for_computes.enabled=true \
      --set conf.ceph.enabled=true \
      $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c nova ${FEATURES}) \
      -f ${K3S_OVERRIDES_DIR}/nova.yaml \
      --timeout 30m

    PROVIDER_INTERFACE=$NIC
    cat > ${K3S_OVERRIDES_DIR}/neutron.yaml <<-EOF
conf:
  neutron:
    DEFAULT:
      l3_ha: False
      max_l3_agents_per_router: 1
  auto_bridge_add:
    br-ex: ${PROVIDER_INTERFACE}
  plugins:
    ml2_conf:
      ml2_type_flat:
        flat_networks: public
    openvswitch_agent:
      ovs:
        bridge_mappings: public:br-ex
EOF

    helm_safe_install_nonblocking neutron neutron openstack "${HELM_OSH_REPO_URL}" \
      $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c neutron ${FEATURES}) \
      -f ${K3S_OVERRIDES_DIR}/neutron.yaml \
      --timeout 30m

    helm osh wait-for-pods openstack

    ok "Compute Kit deployed successfully"
fi

# require_cmd helm
# require_cmd jq

LISTEN_IP_ADDRESS="${LISTEN_IP_ADDRESS:-0.0.0.0}"

if [[ "$LIBVIRT" -eq 1 ]]; then
  info "Deploying Libvirt..."

  cat > "${K3S_OVERRIDES_DIR}/libvirt-values.yaml" <<EOF
conf:
  qemu:
    vnc_tls: "0"
    vnc_tls_x509_verify: "0"
    stdio_handler: "file"
    user: "nova"
    group: "kvm"
    cgroup_device_acl:
      - "/dev/null"
      - "/dev/full"
      - "/dev/zero"
      - "/dev/random"
      - "/dev/urandom"
      - "/dev/ptmx"
      - "/dev/kvm"

  libvirt:
    listen_tcp: "1"
    listen_tls: "0"
    auth_tcp: "none"
    auth_unix_rw: "none"
    listen_addr: "${LISTEN_IP_ADDRESS}"

pod:
  security_context:
    libvirt:
      pod:
        runAsUser: 0
        hostNetwork: true
        hostPID: true
        hostIPC: true
      container:
        libvirt:
          privileged: true
          readOnlyRootFilesystem: false

mounts:
  libvirt:
    libvirt:
      volumeMounts:
        - name: dev-kvm
          mountPath: /dev/kvm
      volumes:
        - name: dev-kvm
          hostPath:
            path: /dev/kvm
            type: CharDevice
EOF

  helm_safe_install_nonblocking libvirt libvirt openstack "${HELM_OSH_REPO_URL}" \
    --set conf.ceph.enabled=true \
    $(helm osh get-values-overrides -p "${OVERRIDES_DIR}" -c libvirt ${FEATURES} 2>/dev/null || true) \
    -f "${K3S_OVERRIDES_DIR}/libvirt-values.yaml" \
    --timeout 10m

  info "Libvirt chart installed. Not waiting for libvirt pods yet; Neutron OVS agents are installed later."

  ok "Libvirt deployed"
fi

ok "OSH installation complete"
