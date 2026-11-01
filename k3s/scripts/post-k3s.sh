#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source all libraries
source "$BASE_DIR/lib/colors.sh"

INOTIFY_WATCHES=524288
INOTIFY_INSTANCES=8192
INOTIFY_EVENTS=65536
NOFILE_LIMIT=1048576

info "Disabling swap"

# Turn off swap immediately
if sudo swapoff -a; then
    ok "Swap turned off successfully"
else
    warn "Could not turn off swap (maybe already off?)"
fi

if grep -q "swap" /etc/fstab; then
    sudo cp /etc/fstab /etc/fstab.bak
    sudo sed -i.bak '/swap/s/^/#/' /etc/fstab
    ok "Disabled swap permanently (fstab entries commented)"
else
    warn "No swap entries found in /etc/fstab"
fi

info "Raising inotify limits"

sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=8192

cat > /etc/sysctl.d/99-inotify.conf <<EOF
fs.inotify.max_user_watches = ${INOTIFY_WATCHES}
fs.inotify.max_user_instances = ${INOTIFY_INSTANCES}
fs.inotify.max_queued_events = ${INOTIFY_EVENTS}
EOF

sudo sysctl --system

ok "Raised permanently inotify limits"

info "Raising open-file limits for k3s/containerd (systemd)"

info "Detecting node role..."
if systemctl list-units --type=service | grep k3s.service; then
    ROLE="server"
    SERVICE="k3s"
elif systemctl list-units --type=service | grep k3s-agent.service; then
    ROLE="agent"
    SERVICE="k3s-agent"
else
    err "Neither k3s nor k3s-agent service found. Exiting."
    exit 1
fi

info "Configuring systemd override for ${SERVICE}.service..."

sudo mkdir -p /etc/systemd/system/${SERVICE}.service.d
cat > /etc/systemd/system/${SERVICE}.service.d/override.conf >/dev/null <<EOF
[Service]
LimitNOFILE=${NOFILE_LIMIT}
EOF

info "Reloading systemd and restarting ${SERVICE}..."
sudo systemctl daemon-reload
sudo systemctl restart ${SERVICE}

ok "Raised open-file limits for k3s/containerd (systemd)"
