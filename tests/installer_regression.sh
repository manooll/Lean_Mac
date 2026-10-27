#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
bash -n install.sh
# The standalone path must use the tested distribution and repair existing jobs.
grep -Fq 'RAW_BASE_URL="${LEAN_MAC_RAW_BASE_URL:-https://raw.githubusercontent.com/realnoedelo/Lean_Mac/main}"' install.sh
grep -Fq 'com.user.disablebloatservices.agent' install.sh
grep -Fq 'https://raw.githubusercontent.com/realnoedelo/Lean_Mac/main/install.sh' README.md
if rg -n -i 'Jay L\.|Manull|github\.com/manooll' README.md install.sh restore_macos_services.sh; then
  echo 'upstream author/repository identity leaked into the fork' >&2
  exit 1
fi
grep -Fq 'launchctl bootout system "$daemon_plist"' install.sh
grep -Fq 'launchctl load -w "$daemon_plist"' install.sh
grep -Fq 'launchctl load -w "$agent_plist"' install.sh
grep -Fq '<string>--system-only</string>' install.sh
grep -Fq '<string>--user-only</string>' install.sh
grep -Fq '/var/log/disable_bloat_services.error.log' install.sh
grep -Fq 'Library/Logs/disable_bloat_services.error.log' install.sh
grep -Fq 'rotate_error_logs' install.sh
grep -Fq 'remove_previous_installation' install.sh
grep -Fq 'PROFILE_FILE="$CONFIG_DIR/lean_mac.conf"' install.sh
grep -Fq 'choose_profile' install.sh
if rg -n -U '<key>KeepAlive</key>\s*<true/>' install.sh; then
  echo 'periodic jobs must not use KeepAlive=true' >&2
  exit 1
fi
grep -Fq 'launchctl bootout "gui/$user_uid/$agent_label"' install.sh
grep -Fq 'LOG_FILE="/var/log/disable_bloat_services.log"' disable_bloat_services.sh
if grep -Fq 'kickstart -k "gui/$user_uid/com.user.disablebloatservices"' install.sh; then
  echo 'stale LaunchAgent label remains' >&2
  exit 1
fi
echo 'installer regression checks passed'
