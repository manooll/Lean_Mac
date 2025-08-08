#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
shellcheck disable_bloat_services.sh cleanup_caches.sh install.sh restore_macos_services.sh
