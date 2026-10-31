#!/bin/bash

BOLD="$(tput bold || true)"; RESET="$(tput sgr0 || true)"
BLUE="\033[96m"
YELLOW="\033[93m"
RED="\033[31m"
MAGENTA="\033[35m"

info() { echo -e "${BOLD}[*]${RESET} ${BLUE}$*${RESET}"; }
ok()   { echo -e "${BOLD}[✓]${RESET} ${MAGENTA}$*${RESET}"; }
warn() { echo -e "${BOLD}[!]${RESET} ${YELLOW}$*${RESET}"; }
err()  { echo -e "${BOLD}[x]${RESET} ${RED}$*${RESET}" >&2; }
