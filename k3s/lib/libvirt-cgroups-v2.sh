#!/bin/bash

{{/*
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}

# This is a modified version of libvirt.sh that supports cgroups v2
# It replaces cgcreate (cgroups v1 tool) with mkdir (cgroups v2 compatible)

set -ex

# Check if any libvirtd process is already running  
if [[ -n $(pgrep libvirtd) ]]; then
  echo "Libvirtd already running, exiting"
  exit 0
fi

rm -f /var/run/libvirtd.pid

# Setup KVM device permissions
if [[ -c /dev/kvm ]]; then
  chmod 660 /dev/kvm
  chown root:kvm /dev/kvm
fi

# Build cgroup controller list
CGROUPS=""
for CGROUP in {{ include "helm-toolkit.utils.joinListWithComma" .Values.conf.kubernetes.cgroup_controllers }}; do
  # Check if in v1 location
  if [[ -d /sys/fs/cgroup/${CGROUP} ]]; then
    CGROUPS+="${CGROUP},"
  # Check if controller exists in unified v2 hierarchy
  elif grep -qw ${CGROUP} /sys/fs/cgroup/cgroup.controllers 2>/dev/null; then
    CGROUPS+="${CGROUP},"
  fi
done

# Remove trailing comma
CGROUPS=${CGROUPS%,}

if [[ -n "${CGROUPS}" ]]; then
  # Detect cgroups v2 by checking for cgroup.controllers file
  if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    echo "Detected cgroups v2 unified hierarchy"
    CGROUP_PATH="/sys/fs/cgroup/osh-libvirt"
    
    # Create the cgroup directory if it doesn't exist
    if [[ ! -d "${CGROUP_PATH}" ]]; then
      mkdir -p "${CGROUP_PATH}"
      echo "Created cgroup directory: ${CGROUP_PATH}"
    else
      echo "Cgroup directory already exists: ${CGROUP_PATH}"
    fi
    
    # Enable controllers in the cgroup's parent
    if [[ -f /sys/fs/cgroup/cgroup.subtree_control ]]; then
      AVAILABLE=$(cat /sys/fs/cgroup/cgroup.controllers)
      echo "Available controllers: ${AVAILABLE}"
      
      # Enable controllers for our cgroup
      for CTRL in ${CGROUPS//,/ }; do
        if echo "${AVAILABLE}" | grep -qw "${CTRL}"; then
          # Try to enable the controller, ignore errors if already enabled
          echo "+${CTRL}" >> /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || \
            echo "Controller ${CTRL} already enabled or permission denied"
        else
          echo "Warning: Controller ${CTRL} not available in cgroups v2"
        fi
      done
      
      echo "Successfully configured cgroups v2 for libvirt"
    fi
  else
    # Fall back to cgcreate for cgroups v1 (shouldn't happen on k3s)
    echo "Detected cgroups v1, using cgcreate"
    cgcreate -g ${CGROUPS}:/osh-libvirt
  fi
fi

# Start libvirtd
exec /usr/sbin/libvirtd --listen
