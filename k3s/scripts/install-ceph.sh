#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source all libraries
source "$BASE_DIR/lib/colors.sh"
source "$BASE_DIR/lib/atomic_helm.sh"

MGMT_DOMAIN="${MGMT_DOMAIN:-int.cloud.dev}"
MGMT_INGRESS_CLASS="${MGMT_INGRESS_CLASS:-traefik}"

OPENSTACK_NS="${OPENSTACK_NS:-openstack}"
HELM_OSH_REPO_URL="https://tarballs.opendev.org/openstack/openstack-helm"

# --- Rook/Ceph tunables (single-node defaults; override via env) ------------
ROOK_NS="${ROOK_NS:-rook-ceph}"
ROOK_RELEASE="${ROOK_RELEASE:-v1.17.7}"
ROOK_REPO_URL="${ROOK_REPO_URL:-https://charts.rook.io/release}"

CEPH_NS="${CEPH_NS:-ceph}"
CEPH_IMAGE="${CEPH_IMAGE:-quay.io/ceph/ceph:v19.2.3}"
CEPH_MON_REPLICAS="${CEPH_MON_REPLICAS:-5}"
CEPH_MAN_REPLICAS="${CEPH_MAN_REPLICAS:-2}"

CREATE_RBD_SC="${CREATE_RBD_SC:-true}"
RBD_SC_NAME="${RBD_SC_NAME:-ceph-rbd}"
RBD_POOL="${RBD_POOL:-ceph}"

OSD_BACKING_SC="${OSD_BACKING_SC:-longhorn}"
OSD_SIZE="${OSD_SIZE:-10Gi}"
OSD_COUNT="${OSD_COUNT:-5}"

# Ensure kubeconfig for k3s
if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# --- Namespaces --------------------------------------------------------------
info "Creating namespaces"
kubectl create namespace "${CEPH_NS}" 2>/dev/null || true
kubectl create namespace "${ROOK_NS}" 2>/dev/null || true
kubectl create namespace "${OPENSTACK_NS}" 2>/dev/null || true

# --- Add Helm repos & plugins -----------------------------------
info "Adding Helms Repo & Plugin"
helm repo add rook-release "${ROOK_REPO_URL}" >/dev/null 2>&1 || true
helm repo add openstack-helm "$HELM_OSH_REPO_URL" >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

helm cache clean 2>/dev/null || true

# --- Deploy Rook operator -------------------------------------------------------------
info "Deploying Rook-Ceph operator..."

cat > /tmp/rook.yaml <<EOF
image:
  repository: rook/ceph
  tag: ${ROOK_RELEASE}
  pullPolicy: IfNotPresent
crds:
  enabled: true
nodeSelector: {}
tolerations: []
unreachableNodeTolerationSeconds: 5
currentNamespaceOnly: false
annotations: {}
logLevel: INFO
rbacEnable: true
pspEnable: false
priorityClassName:
allowLoopDevices: true
csi:
  enableRbdDriver: true
  enableCephfsDriver: false
  enableGrpcMetrics: false
  enableCSIHostNetwork: true
  enableCephfsSnapshotter: true
  enableNFSSnapshotter: true
  enableRBDSnapshotter: true
  enablePluginSelinuxHostMount: false
  enableCSIEncryption: false
  pluginPriorityClassName: system-node-critical
  provisionerPriorityClassName: system-cluster-critical
  rbdFSGroupPolicy: "File"
  cephFSFSGroupPolicy: "File"
  nfsFSGroupPolicy: "File"
  enableOMAPGenerator: false
  cephFSKernelMountOptions:
  enableMetadata: false
  provisionerReplicas: 1
  clusterName: ceph
  logLevel: 0
  sidecarLogLevel:
  rbdPluginUpdateStrategy:
  rbdPluginUpdateStrategyMaxUnavailable:
  cephFSPluginUpdateStrategy:
  nfsPluginUpdateStrategy:
  grpcTimeoutInSeconds: 150
  allowUnsupportedVersion: false
  csiRBDPluginVolume:
  csiRBDPluginVolumeMount:
  csiCephFSPluginVolume:
  csiCephFSPluginVolumeMount:
  provisionerTolerations:
  provisionerNodeAffinity: #key1=value1,value2; key2=value3
  pluginTolerations:
  pluginNodeAffinity: # key1=value1,value2; key2=value3
  enableLiveness: false
  cephfsGrpcMetricsPort:
  cephfsLivenessMetricsPort:
  rbdGrpcMetricsPort:
  csiAddonsPort:
  forceCephFSKernelClient: true
  rbdLivenessMetricsPort:
  kubeletDirPath:
  cephcsi:
    image:
  registrar:
    image:
  provisioner:
    image:
  snapshotter:
    image:
  attacher:
    image:
  resizer:
    image:
  imagePullPolicy: IfNotPresent
  cephfsPodLabels: #"key1=value1,key2=value2"
  nfsPodLabels: #"key1=value1,key2=value2"
  rbdPodLabels: #"key1=value1,key2=value2"
  csiAddons:
    enabled: false
    image: "quay.io/csiaddons/k8s-sidecar:v0.5.0"
  nfs:
    enabled: false
  topology:
    enabled: false
    domainLabels:
  readAffinity:
    enabled: false
    crushLocationLabels:
  cephFSAttachRequired: true
  rbdAttachRequired: true
  nfsAttachRequired: true
enableDiscoveryDaemon: false
cephCommandsTimeoutSeconds: "15"
useOperatorHostNetwork:
discover:
  toleration:
  tolerationKey:
  tolerations:
  nodeAffinity: # key1=value1,value2; key2=value3
  podLabels: # "key1=value1,key2=value2"
  resources:
disableAdmissionController: true
hostpathRequiresPrivileged: false
disableDeviceHotplug: false
discoverDaemonUdev:
imagePullSecrets:
enableOBCWatchOperatorNamespace: true
admissionController:
EOF

helm_safe_install_atomic rook-ceph rook-ceph "${ROOK_NS}" "${ROOK_REPO_URL}" \
    --version ${ROOK_RELEASE} -f /tmp/rook.yaml \
    --wait --timeout 10m

helm osh wait-for-pods ${ROOK_NS}

# Ceph cluster using explicit raw devices per node (no Longhorn)

cat > /tmp/ceph-rawdisks-per-node.yaml <<EOF
operatorNamespace: ${ROOK_NS}
clusterName: ceph
kubeVersion: null

configOverride: |
  [global]
  mon_allow_pool_delete = true
  mon_allow_pool_size_one = true
  osd_pool_default_size = 1
  osd_pool_default_min_size = 1
  mon_warn_on_pool_no_redundancy = false
  auth_allow_insecure_global_id_reclaim = false
  [mgr]
  mgr_initial_modules = rook, orchestrator_cli

toolbox:
  enabled: true
  tolerations: []
  affinity: {}
  resources:
    limits:
      cpu: "100m"
      memory: "64Mi"
    requests:
      cpu: "100m"
      memory: "64Mi"
  priorityClassName: null

monitoring:
  enabled: false
  metricsDisabled: true
  createPrometheusRules: false
  rulesNamespaceOverride: null
  prometheusRule:
    labels: {}
    annotations: {}

pspEnable: false

cephClusterSpec:
  cephVersion:
    image: ${CEPH_IMAGE}
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  skipUpgradeChecks: false
  continueUpgradeAfterChecksEvenIfNotHealthy: false
  waitTimeoutForHealthyOSDInMinutes: 10

  mon:
    count: ${CEPH_MON_REPLICAS}
    allowMultiplePerNode: false

  mgr:
    count: ${CEPH_MAN_REPLICAS}
    allowMultiplePerNode: false
    modules:
      - name: pg_autoscaler
        enabled: true
      - name: dashboard
        enabled: false
      - name: nfs
        enabled: false
      - name: rook
        enabled: true
      - name: orchestrator_cli
        enabled: true

  resources:
    mon:
      requests:
        cpu: "100m"
        memory: "512Mi"
      limits:
        memory: "1Gi"
    mgr:
      requests:
        cpu: "100m"
        memory: "512Mi"
      limits:
        memory: "1Gi"
    osd:
      requests:
        cpu: "200m"
        memory: "1Gi"
      limits:
        memory: "2Gi"
    prepareosd:
      requests:
        cpu: "100m"
        memory: "512Mi"
      limits:
        memory: "1Gi"

  dashboard:
    enabled: true
    ssl: false

  # Pod networking to avoid host port conflicts
  network:
    provider: ""
    connections:
      encryption:
        enabled: false
      compression:
        enabled: false
      requireMsgr2: false

  crashCollector:
    disable: true

  logCollector:
    enabled: true
    periodicity: daily
    maxLogSize: "500M"

  cleanupPolicy:
    confirmation: ""
    sanitizeDisks:
      method: quick
      dataSource: zero
      iteration: 1
    allowUninstallWithVolumes: false

  monitoring:
    enabled: false
    metricsDisabled: true

  removeOSDsIfOutAndSafeToRemove: false

  priorityClassNames:
    mon: system-node-critical
    osd: system-node-critical
    mgr: system-cluster-critical

  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: snode1
        devices:
          - name: vdc
      - name: snode2
        devices:
          - name: vdc
      - name: snode3
        devices:
          - name: vdc
      - name: snode4
        devices:
          - name: vdc
      - name: snode5
        devices:
          - name: vdc          
    config:
      osdsPerDevice: "1"
      storeType: bluestore
      encryptedDevice: "false"

  disruptionManagement:
    managePodBudgets: true
    osdMaintenanceTimeout: 30
    pgHealthCheckTimeout: 0

  healthCheck:
    daemonHealth:
      mon:
        disabled: false
        interval: 45s
      osd:
        disabled: false
        interval: 60s
      status:
        disabled: false
        interval: 60s
    livenessProbe:
      mon:
        disabled: false
      mgr:
        disabled: false
      osd:
        disabled: false

ingress:
  dashboard:
    enabled: true
    ingressClassName: ${MGMT_INGRESS_CLASS}
    host:
      name: ceph.${MGMT_DOMAIN}
      path: /
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"

cephBlockPools:
  - name: rdb
    namespace: ceph
    spec:
      failureDomain: osd
      replicated:
        size: 1
        requireSafeReplicaSize: false
    storageClass:
      enabled: true
      name: general
      isDefault: false
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      volumeBindingMode: Immediate
      mountOptions: []
      allowedTopologies: []
      parameters:
        imageFormat: "2"
        imageFeatures: layering
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: "{{ .Release.Namespace }}"
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: "{{ .Release.Namespace }}"
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
        csi.storage.k8s.io/node-stage-secret-namespace: "{{ .Release.Namespace }}"
        csi.storage.k8s.io/fstype: ext4

cephFileSystems: []

cephBlockPoolsVolumeSnapshotClass:
  enabled: false
  name: general
  isDefault: false
  deletionPolicy: Delete
  annotations: {}
  labels: {}
  parameters: {}

cephObjectStores:
  - name: default
    namespace: ceph
    spec:
      allowUsersInNamespaces:
        - "*"
      metadataPool:
        failureDomain: host
        replicated:
          size: 1
      dataPool:
        failureDomain: host
        replicated:
          size: 1
      preservePoolsOnDelete: true
      gateway:
        port: 8080
        securePort: null
        sslCertificateRef: null
        instances: 1
        priorityClassName: system-cluster-critical
        resources:
          requests:
            cpu: "100m"
            memory: "512Mi"
          limits:
            memory: "1Gi"
    storageClass:
      enabled: true
      name: ceph-bucket
      reclaimPolicy: Delete
      volumeBindingMode: Immediate
EOF


info "Deploying Ceph cluster..."
info "CEPH_MAN_REPLICAS: ${CEPH_MAN_REPLICAS}, CEPH_MON_REPLICAS: ${CEPH_MON_REPLICAS}, OSD_COUNT: ${OSD_COUNT}"

helm_safe_install_atomic rook-ceph-cluster rook-ceph-cluster "${CEPH_NS}" "${ROOK_REPO_URL}" \
    --version ${ROOK_RELEASE} -f /tmp/ceph-rawdisks-per-node.yaml \
    --wait --timeout 30m
  
helm osh wait-for-pods ${ROOK_NS}
helm osh wait-for-pods ${CEPH_NS}

ok "Ceph Dashboard password:"
kubectl -n ceph get secret rook-ceph-dashboard-password -o jsonpath='{.data.password}' | base64 --decode && echo

ok "Rook/Ceph deployed successfully"
