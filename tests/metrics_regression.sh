#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
bash -n disable_bloat_services.sh
# Post-increment returns status 1 under set -e and previously killed the run.
if rg -n '\(\([A-Z_]+\+\+\)\)' disable_bloat_services.sh; then
  echo 'unsafe post-increment remains' >&2
  exit 1
fi
grep -Fq 'Available RAM before' disable_bloat_services.sh
grep -Fq 'Available RAM after' disable_bloat_services.sh
grep -Fq 'RAM change' disable_bloat_services.sh
grep -Fq 'Processes respawned/SIP-protected' disable_bloat_services.sh
grep -Fq 'Target-process RSS before' disable_bloat_services.sh
grep -Fq 'Target RSS change' disable_bloat_services.sh
grep -Fq 'Services protected' disable_bloat_services.sh
grep -Fq 'Services already disabled' disable_bloat_services.sh
grep -Fq 'Services re-enabled' disable_bloat_services.sh
grep -Fq 'Total service decisions' disable_bloat_services.sh
grep -Fq 'get_gui_uids' disable_bloat_services.sh
grep -Fq 'MODE" != "user-only' disable_bloat_services.sh
if grep -Fq 'launchctl print "gui/$(id -u)"' disable_bloat_services.sh; then
  echo 'root GUI verification must not query gui/0' >&2
  exit 1
fi
echo 'metrics and GUI-domain regression checks passed'
