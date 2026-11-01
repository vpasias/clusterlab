#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source all libraries
source "$BASE_DIR/lib/colors.sh"
source "$BASE_DIR/lib/atomic_helm.sh"

NIC="${NIC:-enp1s0}"

require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }; }

# Ensure kubeconfig for k3s
if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/rancher/k3s/k3s.yaml ]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# --- System prep -------------------------------------------------------------
info "Preparing OSH master node"
info "Updating apt & installing base tools…"
sudo apt-get update -y
sudo apt-get install -y git curl ca-certificates gnupg lsb-release jq

  # Get eth0 IP address
  ETH0_IP=$(ip -4 addr show enp1s0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
  
  if [ -z "$ETH0_IP" ]; then
    err "Could not detect eth0 IP address"
    exit 1
  fi

# --- k3s install (if needed) -------------------------------------------------
if ! command -v k3s >/dev/null 2>&1; then
  info "Installing k3s master…"  
  info "Using eth0 IP: $ETH0_IP"
  
  sudo curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="server \
    --flannel-iface enp1s0 --tls-san 172.19.123.254 --cluster-init --token k3svip --bind-address $ETH0_IP" sh -
  
  if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  fi

else
  ok "k3s already present."
fi

info "Creating/Updating Traefik HelmChartConfig..."
  sudo mkdir -p /var/lib/rancher/k3s/server/manifests/

  sudo tee /var/lib/rancher/k3s/server/manifests/traefik-config.yaml > /dev/null <<EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    ports:
      web:
        port: 80
        expose:
          default: true
        exposedPort: 8080
      websecure:
        port: 443
        expose:
          default: true
        exposedPort: 8443
EOF

info "Waiting for Traefik to deploy..."
  i=0
  while [ $i -lt 60 ]; do
    i=$((i + 1))
    
    # Check if job exists and get its status
    JOB_STATUS=$(sudo k3s kubectl -n kube-system get job helm-install-traefik -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")
    
    if [ "$JOB_STATUS" = "True" ]; then
      ok "K3s installed with Traefik exposed on: HTTP/8080, HTTPS/8443 via $ETH0_IP"
      break
    fi
    
    sleep 2
  done
  
  if [ $i -ge 60 ]; then
    warn "Traefik installation did not complete within timeout"
  fi

warn "You need to manually add the external IP addresses to your DNS, after all worker nodes join the cluster"
kubectl get svc traefik -n kube-system

# --- kubeconfig copy to ~/.kube/config

KUBE_PWD=/home/$SUDO_USER/.kube
mkdir -p $KUBE_PWD
cp /etc/rancher/k3s/k3s.yaml $KUBE_PWD/config
ok "Copied /etc/rancher/k3s/k3s.yaml to $KUBE_PWD/config"

# kubectl (k3s provides shim)
if ! command -v kubectl >/dev/null 2>&1; then
  export PATH="/usr/local/bin:$PATH"
fi
require_cmd kubectl
ok "Kubernetes nodes:"
kubectl get nodes -o wide

# --- Helm install (if needed) ------------------------------------------------
if ! command -v helm >/dev/null 2>&1; then
  info "Installing Helm 3…"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  ok "Helm already present."
fi

info "Installing Helm OSH Plugin..."
helm plugin install https://opendev.org/openstack/openstack-helm-plugin.git >/dev/null 2>&1 || true
ok "Helm OSH Plugin installed"

# --- K9s install (if not present) -------------------------------------------
if ! command -v k9s >/dev/null 2>&1; then
  info "Installing K9s (Kubernetes TUI)…"
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac
  TMP_DIR=$(mktemp -d)
  K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
  curl -L -o "$TMP_DIR/k9s.tar.gz" "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz"
  tar -xzf "$TMP_DIR/k9s.tar.gz" -C "$TMP_DIR"
  sudo mv "$TMP_DIR/k9s" /usr/local/bin/k9s
  sudo chmod +x /usr/local/bin/k9s
  rm -rf "$TMP_DIR"
  ok "K9s installed → run 'k9s' to open the cluster dashboard."
else
  ok "K9s already present."
fi

# --- k3s (generate join command) -------------------------------------------

MASTER_IP=$(ip -4 addr show $NIC | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
if [[ ! -f "$TOKEN_FILE" ]]; then
    err "token file not found at $TOKEN_FILE"
    exit 1
fi

NODE_TOKEN=$(sudo cat "$TOKEN_FILE")
JOIN_CMD="sudo curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN=${NODE_TOKEN} INSTALL_K3S_EXEC=\"agent --flannel-iface enp1s0\" sh -"

warn "Use the following command on your worker nodes to join the cluster:"
echo
echo "$JOIN_CMD"
echo
