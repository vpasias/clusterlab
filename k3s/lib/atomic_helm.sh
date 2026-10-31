#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source all libraries
source "$BASE_DIR/lib/colors.sh"

# Trap handler for cleanup on interrupt or failure
helm_cleanup_on_failure() {
  local release="$1"
  local ns="$2"
  local revision_before="$3"
  
  warn "Installation interrupted or failed for ${release}"
  
  # Check current state
  if helm -n "$ns" status "$release" >/dev/null 2>&1; then
    local current_revision
    current_revision=$(helm -n "$ns" history "$release" --max 1 -o json 2>/dev/null | jq -r '.[0].revision // 0')
    
    if [[ "$revision_before" -gt 0 ]]; then
      # There was a previous revision, rollback to it
      warn "Rolling back ${release} to revision ${revision_before}..."
      if helm -n "$ns" rollback "$release" "$revision_before" --wait --timeout=5m; then
        ok "Successfully rolled back ${release} to revision ${revision_before}"
      else
        err "Rollback failed for ${release}, attempting uninstall..."
        helm -n "$ns" uninstall "$release" --wait || true
      fi
    else
      # No previous revision, this was a fresh install - uninstall it
      warn "No previous revision found, uninstalling ${release}..."
      if helm -n "$ns" uninstall "$release" --wait --timeout=5m; then
        ok "Successfully uninstalled ${release}"
      else
        err "Uninstall failed for ${release}, manual cleanup may be required"
      fi
    fi
  else
    warn "Release ${release} not found in namespace ${ns}, skipping cleanup"
  fi
}

helm_safe_install () {
  # Usage: helm_safe_install <release> <chart> <namespace> [extra-args...]
  # Example: helm_safe_install mariadb mariadb osh-infra --atomic --wait
  local release="$1"; shift
  local chart="$1"; shift
  local ns="$1"; shift
  local extra=("$@")
  
  # Get the current revision before attempting upgrade (0 if release doesn't exist)
  local revision_before=0
  if helm -n "$ns" status "$release" >/dev/null 2>&1; then
    revision_before=$(helm -n "$ns" history "$release" --max 1 -o json 2>/dev/null | jq -r '.[0].revision // 0')
  fi
  
  info "Installing/upgrading ${release} (current revision: ${revision_before})"
  
  # Set up trap to handle Ctrl-C and failures
  trap "helm_cleanup_on_failure '$release' '$ns' '$revision_before'; return 1" INT TERM
  
  local install_success=0
  local tmpdir=""
  
  # Try direct from repo URL (avoids alias confusion)
  if helm upgrade --install "$release" "$chart" \
        --repo "$HELM_OSH_REPO_URL" -n "$ns" "${extra[@]}"; then
    install_success=1
  else
    warn "Direct repo install failed for $release/$chart — trying pull+untar fallback…"
    # Pull packaged chart with vendored dependencies and install from path
    tmpdir="$(mktemp -d)"
    if helm pull "$chart" --repo "$HELM_OSH_REPO_URL" --untar --untardir "$tmpdir"; then
      if helm upgrade --install "$release" "$tmpdir/$chart" -n "$ns" "${extra[@]}"; then
        install_success=1
      fi
    else
      err "Failed to pull chart $chart from $HELM_OSH_REPO_URL"
    fi
    [[ -n "$tmpdir" ]] && rm -rf "$tmpdir"
  fi
  
  # Clear the trap
  trap - INT TERM
  
  if [[ "$install_success" -eq 1 ]]; then
    ok "Successfully installed/upgraded ${release}"
    return 0
  else
    err "Installation failed for ${release}"
    helm_cleanup_on_failure "$release" "$ns" "$revision_before"
    return 1
  fi
}

helm_safe_install_atomic () {
  local release="$1"; shift
  local chart="$1"; shift
  local ns="$1"; shift
  local repo_url="${1:-}"; local used_repo=""; local extra=()
  if [[ -n "$repo_url" ]]; then used_repo="$repo_url"; shift; fi
  extra=("$@")

  local is_fresh=0
  helm -n "$ns" status "$release" >/dev/null 2>&1 || is_fresh=1

  info "Installing/upgrading ${release} (atomic)"
  [[ "$is_fresh" -eq 1 ]] && trap "warn 'Interrupted'; helm -n '$ns' uninstall '$release' --wait 2>/dev/null || true; exit 1" INT TERM

  if [[ -n "$used_repo" ]]; then
    if helm upgrade --install "$release" "$chart" --repo "$used_repo" -n "$ns" --atomic "${extra[@]}"; then
      ok "Installed ${release}"
      trap - INT TERM
      return 0
    fi
    warn "Repo install failed for ${release}; trying pull+untar…"
    local tmpdir; tmpdir="$(mktemp -d)"
    if helm pull "$chart" --repo "$used_repo" --untar --untardir "$tmpdir" && \
       helm upgrade --install "$release" "$tmpdir/$chart" -n "$ns" --atomic "${extra[@]}"; then
      ok "Installed ${release} (pulled)"
      rm -rf "$tmpdir"; trap - INT TERM; return 0
    fi
    rm -rf "$tmpdir"; trap - INT TERM; err "Install failed for ${release}"; return 1
  else
    if helm upgrade --install "$release" "$chart" -n "$ns" --atomic "${extra[@]}"; then
      ok "Installed ${release}"
      trap - INT TERM
      return 0
    fi
    err "Install failed for ${release}"
    [[ "$is_fresh" -eq 1 ]] && helm -n "$ns" uninstall "$release" --wait 2>/dev/null || true
    trap - INT TERM
    return 1
  fi
}

helm_safe_install_nonblocking () {
  local release="$1"; shift
  local chart="$1"; shift
  local ns="$1"; shift
  local repo_url="${1:-}"; local used_repo=""; local extra=()
  if [[ -n "$repo_url" ]]; then used_repo="$repo_url"; shift; fi
  extra=("$@")

  local is_fresh=0
  helm -n "$ns" status "$release" >/dev/null 2>&1 || is_fresh=1

  info "Installing/upgrading ${release} (non-blocking)"

  # Remove --atomic and --wait flags from extra if present
  local filtered_extra=()
  for arg in "${extra[@]}"; do
    if [[ "$arg" != "--atomic" && "$arg" != "--wait" ]]; then
      filtered_extra+=("$arg")
    fi
  done

  if [[ -n "$used_repo" ]]; then
    if helm upgrade --install "$release" "$chart" --repo "$used_repo" -n "$ns" "${filtered_extra[@]}" >/dev/null 2>&1 &
    then
      ok "Started installation of ${release} (background)"
      return 0
    else
      warn "Repo install failed for ${release}; trying pull+untar…"
      local tmpdir; tmpdir="$(mktemp -d)"
      if helm pull "$chart" --repo "$used_repo" --untar --untardir "$tmpdir" && \
         helm upgrade --install "$release" "$tmpdir/$chart" -n "$ns" "${filtered_extra[@]}" >/dev/null 2>&1 &
      then
        ok "Started installation of ${release} (pulled, background)"
        rm -rf "$tmpdir"; return 0
      fi
      rm -rf "$tmpdir"; err "Failed to start install for ${release}"; return 1
    fi
  else
    if helm upgrade --install "$release" "$chart" -n "$ns" "${filtered_extra[@]}" >/dev/null 2>&1 &
    then
      ok "Started installation of ${release} (background)"
      return 0
    else
      err "Failed to start install for ${release}"; return 1
    fi
  fi
}

# Helper function to wait for multiple releases
helm_wait_for_releases () {
  local ns="$1"; shift
  local releases=("$@")
  local timeout="${HELM_WAIT_TIMEOUT:-600}"  # 10 minutes default
  local interval=5
  local elapsed=0

  info "Waiting for ${#releases[@]} releases in namespace ${ns}..."
  
  while [[ $elapsed -lt $timeout ]]; do
    local all_ready=1
    local pending_releases=()
    
    for release in "${releases[@]}"; do
      local status
      status=$(helm -n "$ns" status "$release" -o json 2>/dev/null | jq -r '.info.status' 2>/dev/null || echo "unknown")
      
      if [[ "$status" == "deployed" ]]; then
        continue
      elif [[ "$status" == "failed" ]]; then
        err "Release ${release} failed!"
        all_ready=0
        pending_releases+=("${release} (FAILED)")
      else
        all_ready=0
        pending_releases+=("${release} (${status})")
      fi
    done
    
    if [[ $all_ready -eq 1 ]]; then
      ok "All releases ready in namespace ${ns}"
      return 0
    fi
    
    info "Waiting for: ${pending_releases[*]}"
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  
  err "Timeout waiting for releases in namespace ${ns}"
  return 1
}

# Helper to wait for pods specifically
helm_wait_for_release_pods () {
  local ns="$1"
  local release="$2"
  local timeout="${3:-600}"
  
  info "Waiting for pods from release ${release}..."
  kubectl wait --for=condition=ready pod \
    -l "release=${release}" \
    -n "$ns" \
    --timeout="${timeout}s" 2>/dev/null || {
    warn "Some pods from ${release} may not be ready yet"
    return 1
  }
  ok "Pods from ${release} are ready"
  return 0
}
