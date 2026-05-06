#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_INSTALLER="$SCRIPT_DIR/linux/install/AutoGIT-install-linux.sh"

if [[ ! -x "$LINUX_INSTALLER" ]]; then
  echo "[x] Missing Linux installer: $LINUX_INSTALLER" >&2
  exit 1
fi

exec "$LINUX_INSTALLER" "$@"
