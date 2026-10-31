#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)."; exit 1; }

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source all libraries
source "$BASE_DIR/lib/colors.sh"
source "$BASE_DIR/lib/atomic_helm.sh"

DISK="${DISK:-/dev/sdb}"

K3S=0
CEPH=0

for arg in "$@"; do
  case "$arg" in
    --k3s) K3S=1 ;;
    --ceph) CEPH=1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

exists() { command -v "$1" >/dev/null 2>&1; }
run() { "$@" 2>/dev/null || true; }

if [[ "$K3S" -eq 1 ]]; then
    info "Uninstalling k3s..."

    [[ -x /usr/local/bin/k3s-killall.sh ]] && /usr/local/bin/k3s-killall.sh || true
    [[ -x /usr/local/bin/k3s-uninstall.sh ]] && /usr/local/bin/k3s-uninstall.sh || true
    [[ -x /usr/local/bin/k3s-agent-uninstall.sh ]] && /usr/local/bin/k3s-agent-uninstall.sh || true

    # Best-effort stop/disable if scripts weren't present
    run systemctl stop k3s
    run systemctl stop k3s-agent
    run systemctl disable k3s
    run systemctl disable k3s-agent

    info "Cleaning up directories..."
    run rm -rf /etc/rancher/k3s /var/lib/rancher/k3s /var/lib/kubelet "$HOME/.kube"
    run rm -f /etc/systemd/system/k3s.service /etc/systemd/system/k3s-agent.service
    run systemctl daemon-reload

    ok "Removed k3s"
fi

if [[ "$CEPH" -eq 1 ]]; then
    info "Wiping Ceph disks..."

    sgdisk --zap-all $DISK || true
    sfdisk --delete $DISK || true
    wipefs -a $DISK

    ok "Purged Ceph disks"
fi
