#!/bin/bash

# macOS Bloat Service Disabler - Enhanced Version (System Update Safe)
# Disables 32+ unnecessary services while keeping essential ones
# Handles both user and system services + kills running processes
# UPDATED: Added system update protection and safer process handling
# Created: $(date)

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    LOG_FILE="/var/log/disable_bloat_services.log"
else
    LOG_FILE="${HOME:?}/Library/Logs/disable_bloat_services.log"
fi
SCRIPT_PATH="${SCRIPT_PATH:-/usr/local/bin/disable_bloat_services.sh}"
# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# The daemon and agent can fire at the same time. One run must own the log and
# counters so the two jobs do not report duplicate or conflicting results.
LOCK_DIR="${LEAN_MAC_LOCK_DIR:-/tmp/lean-mac-disable-bloat.lock}"
acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$LOCK_DIR/pid"
        return 0
    fi
    local owner_pid=""
    [ -r "$LOCK_DIR/pid" ] && owner_pid=$(cat "$LOCK_DIR/pid")
    if [ -z "$owner_pid" ] || ! kill -0 "$owner_pid" 2>/dev/null; then
        rm -f "$LOCK_DIR/pid" 2>/dev/null || true
        rmdir "$LOCK_DIR" 2>/dev/null || true
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            printf '%s\n' "$$" > "$LOCK_DIR/pid"
            return 0
        fi
    fi
    return 1
}
if ! acquire_lock; then
    exit 0
fi
trap 'rm -f "$LOCK_DIR/pid" 2>/dev/null || true; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
SERVICES_DISABLED=0
SERVICES_FAILED=0
SERVICES_NOT_FOUND=0
SERVICES_PROTECTED=0
SERVICES_ALREADY_DISABLED=0
SERVICES_REENABLED=0
PROCESSES_KILLED=0
PROCESSES_FAILED=0
PROCESSES_SKIPPED=0
PROCESSES_RESPAWNED=0
RAM_BEFORE_BYTES=0
RAM_AFTER_BYTES=0
TARGET_RSS_BEFORE_KB=0
TARGET_RSS_AFTER_KB=0
MODE="auto"
PROFILE="${LEAN_MAC_PROFILE:-balanced}"
CONFIG_FILE="${LEAN_MAC_CONFIG_FILE:-/usr/local/etc/lean_mac.conf}"

load_saved_profile() {
    local saved_profile
    if [ -z "${LEAN_MAC_PROFILE:-}" ] && [ -r "$CONFIG_FILE" ]; then
        saved_profile=$(awk -F= '/^PROFILE=/{print $2; exit}' "$CONFIG_FILE" 2>/dev/null || true)
        [ -n "$saved_profile" ] && PROFILE="$saved_profile"
    fi
}

profile_group_enabled() {
    local group="$1"
    case "$PROFILE" in
        safe|conservative)
            [ "$group" = "telemetry" ]
            ;;
        balanced)
            return 0
            ;;
        custom)
            grep -Fqx "GROUP_${group}=1" "$CONFIG_FILE" 2>/dev/null
            ;;
        *)
            log_message "⚠️  Unknown profile '$PROFILE'; using balanced"
            PROFILE="balanced"
            return 0
            ;;
    esac
}

service_group() {
    case "$1" in
        com.apple.*analytics*|com.apple.*telemetry*|com.apple.feedbackd|com.apple.diagnos*)
            printf '%s\n' telemetry ;;
        com.apple.intelligence*|com.apple.visualintelligence*|com.apple.uiintelligence*|com.apple.siri*|com.apple.assistant*|com.apple.proactive*|com.apple.duet*|com.apple.knowledge*|com.apple.corespotlight*|com.apple.managedcorespotlightd|com.apple.spotlightknowledge*)
            printf '%s\n' intelligence ;;
        com.apple.icloud.searchparty*|com.apple.itunescloudd|com.apple.findmy*|com.apple.icloud.findmy*)
            printf '%s\n' cloud ;;
        com.apple.appstore*|com.apple.weather*|com.apple.mediaremoteagent|com.apple.mediastream*)
            printf '%s\n' store ;;
        com.apple.social*|com.apple.keychainsharing*)
            printf '%s\n' social ;;
        *)
            printf '%s\n' balanced ;;
    esac
}

service_impact() {
    case "$(service_group "$1")" in
        telemetry) printf '%s\n' "reduces analytics/diagnostic activity; no normal feature loss" ;;
        intelligence) printf '%s\n' "may disable Siri, proactive suggestions or Apple Intelligence tasks" ;;
        cloud) printf '%s\n' "may reduce Music/cloud helper refresh; protected Mail and Find My remain" ;;
        store) printf '%s\n' "may delay Weather/App Store/media-remote background updates" ;;
        social) printf '%s\n' "may affect some sharing integrations; Handoff remains protected" ;;
        *) printf '%s\n' "optional background activity" ;;
    esac
}

load_saved_profile

case "${1:-}" in
    --auto|"") MODE="auto" ;;
    --interactive) MODE="interactive" ;;
    --dry-run) MODE="dry-run" ;;
    --list) MODE="list" ;;
    --system-only) MODE="system-only" ;;
    --user-only) MODE="user-only" ;;
    --profile)
        PROFILE="${2:-}"
        [ -n "$PROFILE" ] || { echo "--profile requires a value" >&2; exit 2; }
        ;;
    --help|-h)
        cat <<'USAGE'
Usage: disable_bloat_services.sh [--auto|--interactive|--dry-run|--list]
  --auto          Apply the curated macOS 26/27 list (default).
  --interactive   Ask before each exact launchd label.
  --dry-run       Report checks without disabling anything.
  --list          Read-only inventory of matching labels in system/gui domains.
  --system-only   Run system services and process cleanup (LaunchDaemon mode).
  --user-only     Run GUI services only (LaunchAgent mode).
  --profile NAME  Use safe, balanced, or custom service groups.
USAGE
        exit 0
        ;;
    *) echo "Unknown option: $1 (use --help)" >&2; exit 2 ;;
esac

# launchd entries pass the execution mode first and the profile second.
if [ "${2:-}" = "--profile" ] && [ -n "${3:-}" ]; then
    PROFILE="$3"
fi
if [ "$MODE" = "interactive" ] && [ "${2:-}" != "--profile" ]; then
    PROFILE="balanced"
fi

# System LaunchDaemons checked by their exact launchd labels. Keep this list
# explicit so every target is visible in the log and independently testable.
SYSTEM_SERVICES=(
    "com.apple.wifianalyticsd|WiFi Analytics"
    "com.apple.icloud.findmydeviced|Find My Device"
    "com.apple.ecosystemanalyticsd|Ecosystem Analytics"
    "com.apple.findmy.findmylocateagent|Find My Location"
    "com.apple.findmy.findmymacmessenger|Find My Mac Messenger"
    "com.apple.findmymacd|Find My Mac"
    "com.apple.diagnosticservicesd|Diagnostic Services"
    "com.apple.osanalytics.osanalyticshelper|OS Analytics Helper"
    "com.apple.analyticsd|Analytics Daemon"
    "com.apple.analyticsd.agent|Analytics Agent"
    "com.apple.audioanalyticsd|Audio Analytics"
    "com.apple.usbctelemetryd|USB-C Telemetry"
    "com.apple.cloudtelemetryd|Cloud Telemetry"
    "com.apple.osanalytics.diagnosticmonitor|OS Analytics Monitor"
)

# These labels are deliberately never disabled by automatic or interactive
# modes. They cover Mail/iCloud sync, AirDrop, Exchange and Find My, which the
# installer promises to preserve.
PROTECTED_SERVICES=(
    com.apple.cloudd
    com.apple.icloudmailagent
    com.apple.syncdefaultsd
    com.apple.protectedcloudstorage.protectedcloudkeysyncing
    com.apple.icloud.searchpartyuseragent
    com.apple.icloud.findmydeviced.findmydevice-user-agent
    com.apple.icloud.findmydeviced
    com.apple.findmy.findmylocateagent
    com.apple.findmy.findmybeaconingd
    com.apple.findmymacd
    com.apple.findmymacmessenger
    com.apple.sharingd
    com.apple.rapportd
    com.apple.exchange.exchangesyncd
    # Image text recognition and searchable image metadata (Live Text/OCR).
    # These are functional services, not optional telemetry.
    com.apple.mediaanalysisd
    com.apple.mediaanalysisd-access
    com.apple.visualintelligenced
    com.apple.visualintelligence.daemon-status
    com.apple.uiintelligencesupport.agent
    com.apple.corespotlightd
    com.apple.corespotlightservice
    com.apple.managedcorespotlightd
    com.apple.spotlightknowledged
    com.apple.spotlightknowledged.importer
    com.apple.spotlightknowledged.updater
    com.apple.spotlightknowledged.updater.cachedelete
)

# Processes that support Live Text/OCR, Quick Look metadata and image search.
# Do not terminate them from the automatic cleanup path. A user may still
# select them explicitly in a future interactive mode if that is ever needed.
FUNCTIONAL_PROTECTED_PROCESSES=(
    mediaanalysisd
    visualintelligenced
    corespotlightd
    managedcorespotlightd
    spotlightknowledged
    mdworker
    mds_stores
)

# System Update Protection - Processes that should NEVER be killed
SYSTEM_UPDATE_PROTECTED=(
    "softwareupdate"
    "softwareupdated"
    "mobileassetd"          # Mobile Asset Daemon (System Updates)
    "installd"
    "installer"
    "pkgbuild"
    "packagekitd"
    "system_installd"
    "MobileSoftwareUpdate"
    "SoftwareUpdateNotificationManager"
    "mas"                   # Mac App Store updates
    "App Store"
    "storedownloadd"
    "storeassetd"
    "commerce"
    "CommerceKit"
    "nsurlsessiond"         # Network sessions for downloads
    "cloudd"                # May be needed for update downloads
    "deleted"               # Cache management during updates
    "deleted_helper"        # Cache management helper
    "xpcproxy"              # XPC proxy for system services
    "launchservicesd"       # Launch Services
    "coreservicesd"         # Core Services
    "systemstats"           # System statistics
    "kernel_task"           # Kernel
    "launchd"               # Launch daemon
    "loginwindow"           # Login window
    "WindowServer"          # Window server
    "Finder"                # Finder
    "Dock"                  # Dock
)

# Function to log messages
log_message() {
    local line
    line="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    printf '%s\n' "$line" >> "$LOG_FILE"
    if [ -t 1 ]; then
        printf '%s\n' "$line"
    fi
}

memory_available_bytes() {
    local page_size
    page_size=$(vm_stat | awk '/page size of/{gsub(/[^0-9]/, "", $8); print $8; exit}')
    [ -n "$page_size" ] || page_size=4096
    vm_stat | awk -v ps="$page_size" '
        /Pages free/ || /Pages inactive/ || /Pages speculative/ || /Pages purgeable/ {
            gsub(/[^0-9]/, "", $NF); total += $NF
        }
        END { printf "%.0f", total * ps }
    '
}

format_mb() {
    awk -v bytes="$1" 'BEGIN { printf "%.0f MB", bytes / 1048576 }'
}

target_process_rss_kb() {
    ps -axo rss=,comm= 2>/dev/null | awk '
        /analyticsagent|siriactionsd|siriknowledged|siriinferenced|sirittsd|proactived|intelligenceplatformd|intelligencecontextd|intelligenceflowd|intelligencetasksd|siriappintentsd|feedbackd|knowledge-agent|diagnostics_agent|duetexpertd|inputanalyticsd|analyticsd|audioanalyticsd|ecosystemanalyticsd|osanalyticshelper|proactiveeventtrackerd|wifianalyticsd|geoanalyticsd/ { total += $1 }
        END { printf "%.0f", total + 0 }
    '
}

get_gui_uids() {
    local console_user console_uid sudo_uid
    console_user=$(stat -f '%Su' /dev/console 2>/dev/null || true)
    if [ -n "$console_user" ] && [ "$console_user" != "root" ]; then
        console_uid=$(id -u "$console_user" 2>/dev/null || true)
        [ -n "$console_uid" ] && printf '%s\n' "$console_uid"
    fi
    if [ -n "${SUDO_USER:-}" ]; then
        sudo_uid=$(id -u "$SUDO_USER" 2>/dev/null || true)
        [ -n "$sudo_uid" ] && printf '%s\n' "$sudo_uid"
    fi
}

should_process_service() {
    local service_name="$1"
    local description="$2"
    local domain="$3"
    local protected_service
    local group
    for protected_service in "${PROTECTED_SERVICES[@]}"; do
        if [ "$service_name" = "$protected_service" ]; then
            log_message "🛡️  PRESERVED: $domain/$service_name - $description"
            ((SERVICES_PROTECTED+=1))
            return 1
        fi
    done
    group=$(service_group "$service_name")
    if ! profile_group_enabled "$group"; then
        log_message "⏭️  PROFILE SKIP: $domain/$service_name - $description (group: $group, profile: $PROFILE)"
        return 1
    fi
    case "$MODE" in
        auto) return 0 ;;
        dry-run)
            log_message "🧪 DRY RUN: would check $domain/$service_name - $description"
            return 1
            ;;
        interactive)
            printf 'Disable %s/%s (%s) — impact: %s? [y/N] ' "$domain" "$service_name" "$description" "$(service_impact "$service_name")" > /dev/tty
            read -r answer < /dev/tty || answer=""
            [[ "$answer" =~ ^[Yy]$ ]]
            ;;
    esac
}

service_is_disabled() {
    local domain="$1"
    local service_name="$2"
    local disabled_output
    disabled_output=$(launchctl print-disabled "$domain" 2>/dev/null || true)
    [[ "$disabled_output" == *"\"$service_name\" => disabled"* ]]
}

reenable_protected_service() {
    local domain="$1"
    local service_name="$2"
    local launchctl_cmd=(launchctl)

    if [ "$domain" = "system" ] && [ "$EUID" -ne 0 ]; then
        launchctl_cmd=(sudo launchctl)
    fi

    if ! service_is_disabled "$domain" "$service_name"; then
        return 0
    fi
    if [ "$MODE" = "dry-run" ]; then
        log_message "🧪 DRY RUN: would re-enable protected service $domain/$service_name"
        return 0
    fi
    if "${launchctl_cmd[@]}" enable "$domain/$service_name" 2>/dev/null; then
        log_message "🔓 RE-ENABLED protected service: $domain/$service_name"
        ((SERVICES_REENABLED+=1))
    else
        log_message "⚠️  PROTECTED SERVICE REMAINS DISABLED: $domain/$service_name"
    fi
}

restore_protected_services() {
    local protected_service
    local user_id

    log_message "--- Restoring protected Mail/AirDrop/Find My services ---"
    if [ "$MODE" != "user-only" ]; then
        for protected_service in "${PROTECTED_SERVICES[@]}"; do
            reenable_protected_service "system" "$protected_service"
        done
    fi
    if [ "$MODE" != "system-only" ]; then
        while IFS= read -r user_id; do
            [ -n "$user_id" ] || continue
            for protected_service in "${PROTECTED_SERVICES[@]}"; do
                reenable_protected_service "gui/$user_id" "$protected_service"
            done
        done < <(get_gui_uids | sort -u)
    fi
}

list_matching_services() {
    local domain="$1"
    log_message "🔎 Inventory for $domain:"
    launchctl print "$domain" 2>/dev/null |
        awk '{label=$NF; if (label ~ /^com\.apple\./ && label ~ /(analytics|telemetry|intelligence|siri|spotlight|knowledge|proactive|duet|diagnostic|feedback|mediaanalysis|weather|social|rapport|itunes|commerce)/) print label}' |
        sed 's/[{},]//g' | sort -u | while IFS= read -r label; do
            [ -n "$label" ] && log_message "  $label"
        done
}

# Enhanced function to safely kill processes with system update protection
process_group() {
    case "$1" in
        analyticsagent|feedbackd|diagnostics_agent|wifianalyticsd|geoanalyticsd|analyticsd|audioanalyticsd|ecosystemanalyticsd|osanalyticshelper|inputanalyticsd|proactiveeventtrackerd)
            printf '%s\n' telemetry ;;
        siriactionsd|siriknowledged|siriinferenced|sirittsd|proactived|intelligence*|siriappintentsd|duetexpertd|knowledge-agent|spotlightknowledged*)
            printf '%s\n' intelligence ;;
        commerce|itunescloudd|mediaremoteagent|Music|com.apple.Music)
            printf '%s\n' store ;;
        *)
            printf '%s\n' balanced ;;
    esac
}

kill_process() {
    local process_name="$1"
    local description="$2"
    local group

    if [ "$MODE" = "dry-run" ]; then
        log_message "🧪 DRY RUN: would inspect process $process_name - $description"
        return 0
    fi
    if [ "$MODE" = "user-only" ]; then
        return 0
    fi
    group=$(process_group "$process_name")
    if ! profile_group_enabled "$group"; then
        log_message "⏭️  PROFILE SKIP: process $process_name - $description (group: $group, profile: $PROFILE)"
        return 0
    fi
    
    # Check if this process is protected
    for protected in "${SYSTEM_UPDATE_PROTECTED[@]}"; do
        if [[ "$process_name" == *"$protected"* ]] || [[ "$protected" == *"$process_name"* ]]; then
            log_message "🛡️  PROTECTED: $process_name - $description (System update critical)"
            ((PROCESSES_SKIPPED+=1))
            return 0
        fi
    done
    for protected in "${FUNCTIONAL_PROTECTED_PROCESSES[@]}"; do
        if [ "$process_name" = "$protected" ]; then
            log_message "🛡️  PRESERVED: $process_name - $description (Live Text/OCR and image indexing)"
            ((PROCESSES_SKIPPED+=1))
            return 0
        fi
    done
    
    local pids
    pids=$(pgrep -f "$process_name" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            # Double-check the actual process name to avoid false positives
            local actual_name
            actual_name=$(ps -p "$pid" -o comm= 2>/dev/null | xargs basename)
            
            # Additional protection check on actual process name
            local is_protected=false
            for protected in "${SYSTEM_UPDATE_PROTECTED[@]}"; do
                if [[ "$actual_name" == *"$protected"* ]] || [[ "$protected" == *"$actual_name"* ]]; then
                    log_message "🛡️  PROTECTED: $actual_name (PID: $pid) - System critical process"
                    ((PROCESSES_SKIPPED+=1))
                    is_protected=true
                    break
                fi
            done
            if [ "$is_protected" = false ]; then
                for protected in "${FUNCTIONAL_PROTECTED_PROCESSES[@]}"; do
                    if [ "$actual_name" = "$protected" ]; then
                        log_message "🛡️  PRESERVED: $actual_name (PID: $pid) - Live Text/OCR and image indexing"
                        ((PROCESSES_SKIPPED+=1))
                        is_protected=true
                        break
                    fi
                done
            fi
            
            if [ "$is_protected" = false ]; then
                # Use SIGTERM first, then SIGKILL if needed (gentler approach)
                if kill -TERM "$pid" 2>/dev/null; then
                    sleep 1
                    # Check if process is still running
                    if kill -0 "$pid" 2>/dev/null; then
                        # Still running, use SIGKILL
                        if kill -9 "$pid" 2>/dev/null; then
                            log_message "💀 KILLED: $process_name (PID: $pid) - $description (SIGKILL)"
                            ((PROCESSES_KILLED+=1))
                        else
                            log_message "❌ FAILED TO KILL: $process_name (PID: $pid) - $description"
            ((PROCESSES_FAILED+=1))
                        fi
                    else
                        log_message "✅ TERMINATED: $process_name (PID: $pid) - $description (SIGTERM)"
                            ((PROCESSES_KILLED+=1))
                    fi
                else
                    log_message "❌ FAILED TO TERMINATE: $process_name (PID: $pid) - $description"
                    ((PROCESSES_FAILED+=1))
                fi
            fi
        done
    fi
}

# Function to disable system-level services
disable_system_service() {
    local service_name="$1"
    local description="$2"
    if [ "$MODE" = "user-only" ]; then
        return 0
    fi
    
    local launchctl_cmd=(launchctl)
    local system_services_output
    if [ "$EUID" -ne 0 ]; then
        launchctl_cmd=(sudo launchctl)
    fi

    if ! should_process_service "$service_name" "$description" "system"; then
        return 0
    fi

    system_services_output=$("${launchctl_cmd[@]}" print system 2>/dev/null || true)
    if [[ "$system_services_output" != *"$service_name"* ]]; then
        sleep 1
        system_services_output=$("${launchctl_cmd[@]}" print system 2>/dev/null || true)
    fi
    if [[ "$system_services_output" == *"$service_name"* ]]; then
        if service_is_disabled system "$service_name"; then
            log_message "⏭️  SYSTEM ALREADY DISABLED: $service_name - $description"
            ((SERVICES_ALREADY_DISABLED+=1))
            "${launchctl_cmd[@]}" kill SIGTERM "system/$service_name" 2>/dev/null || true
            return 0
        fi
        if "${launchctl_cmd[@]}" disable "system/$service_name" 2>/dev/null; then
            "${launchctl_cmd[@]}" kill SIGTERM "system/$service_name" 2>/dev/null || true
            log_message "🔴 SYSTEM DISABLED: $service_name - $description"
            ((SERVICES_DISABLED+=1))
        else
            log_message "❌ SYSTEM FAILED: $service_name - $description"
            ((SERVICES_FAILED+=1))
        fi
    else
        log_message "ℹ️  SYSTEM NOT FOUND: $service_name - $description"
        ((SERVICES_NOT_FOUND+=1))
    fi
}

# Function to disable a service for all logged-in users
disable_service() {
    local service_name="$1"
    local description="$2"
    local disabled=false
    local gui_services_output
    if [ "$MODE" = "system-only" ]; then
        return 0
    fi

    if ! should_process_service "$service_name" "$description" "gui"; then
        return 0
    fi
    
    # Check the active console user and the sudo caller's GUI domains.
    for user_id in $(get_gui_uids | sort -u); do
        if [[ "$user_id" =~ ^[0-9]+$ ]] && [ "$user_id" -ge 500 ]; then
            # Try to disable for this user
            gui_services_output=$(launchctl print "gui/$user_id" 2>/dev/null || true)
            if [[ "$gui_services_output" != *"$service_name"* ]]; then
                sleep 1
                gui_services_output=$(launchctl print "gui/$user_id" 2>/dev/null || true)
            fi
            if [[ "$gui_services_output" == *"$service_name"* ]]; then
                if service_is_disabled "gui/$user_id" "$service_name"; then
                    log_message "⏭️  ALREADY DISABLED: $service_name (UID: $user_id)"
                    ((SERVICES_ALREADY_DISABLED+=1))
                    launchctl kill SIGTERM "gui/$user_id/$service_name" 2>/dev/null || true
                    disabled=true
                    continue
                fi
                if launchctl disable "gui/$user_id/$service_name" 2>/dev/null; then
                    launchctl kill SIGTERM "gui/$user_id/$service_name" 2>/dev/null || true
                    log_message "✅ DISABLED: $service_name - $description (UID: $user_id)"
                    disabled=true
                    ((SERVICES_DISABLED+=1))
                else
                    log_message "❌ FAILED: $service_name - $description (UID: $user_id)"
                    ((SERVICES_FAILED+=1))
                fi
            fi
        fi
    done
    
    if [ "$disabled" = false ]; then
        log_message "ℹ️  NOT FOUND: $service_name - $description"
        ((SERVICES_NOT_FOUND+=1))
    fi
}

# Function to check if macOS system updates are running
check_system_updates() {
    # Only look for known update/installer processes and match them exactly
    local update_processes=(
        "softwareupdate"    # Command line macOS updater
        "InstallAssistant"  # macOS GUI installer
        "Installer"         # macOS package installer
    )

    for proc in "${update_processes[@]}"; do
        if pgrep -x "$proc" >/dev/null 2>&1; then
            local pids
            pids=$(pgrep -x "$proc")
            log_message "⚠️  ACTIVE SYSTEM UPDATE DETECTED: $proc (PIDs: $pids)"
            log_message "🛑 ABORTING: Will not run debloat service during system updates"
            log_message "💡 TIP: Try running again after updates complete"
            exit 0
        fi
    done

    # Check specifically for macOS installer apps by their window title
    if pgrep -f "Install macOS" >/dev/null 2>&1; then
        log_message "⚠️  macOS INSTALLER DETECTED - Aborting debloat service"
        exit 0
    fi
}

log_message "=== Starting macOS Bloat Service Disabler (System Update Safe) ==="
log_message "⚙️  Service profile: $PROFILE (config: $CONFIG_FILE)"
RAM_BEFORE_BYTES=$(memory_available_bytes)
TARGET_RSS_BEFORE_KB=$(target_process_rss_kb)
log_message "📊 Available RAM before: $(format_mb "$RAM_BEFORE_BYTES")"
log_message "📊 Target-process RSS before: $(format_mb "$((TARGET_RSS_BEFORE_KB * 1024))")"

if [ "$MODE" = "list" ]; then
    list_matching_services "system"
    for user_id in $(get_gui_uids | sort -u); do
        list_matching_services "gui/$user_id"
    done
    exit 0
fi

log_message "🔍 Checking for active system updates..."
check_system_updates
log_message "✅ No system updates detected - proceeding with debloat service"

# Older releases accidentally disabled some of the services promised as
# preserved. Repair those launchd disable flags before processing bloat.
restore_protected_services

# Cloud & Sync Services (5) - PRESERVING MAIL SERVICES
log_message "--- Disabling Cloud & Sync Services (Preserving Mail) ---"
# PRESERVED: com.apple.cloudd - Required for iCloud Mail sync
# PRESERVED: com.apple.icloudmailagent - Required for iCloud Mail
# PRESERVED: com.apple.syncdefaultsd - Required for Mail sync
# PRESERVED: com.apple.protectedcloudstorage.protectedcloudkeysyncing - May be needed for Mail keychain
disable_service "com.apple.icloud.searchpartyuseragent" "Find My network"
disable_service "com.apple.icloud.findmydeviced.findmydevice-user-agent" "Find My device"
disable_service "com.apple.findmy.findmylocateagent" "Find My location"
disable_service "com.apple.itunescloudd" "iTunes/Music cloud sync"
log_message "✅ PRESERVED: Mail-related services (cloudd, icloudmailagent, syncdefaultsd, protectedcloudstorage)"

# AI & Intelligence Services (12)
log_message "--- Disabling AI & Intelligence Services ---"
disable_service "com.apple.intelligenceplatformd" "Apple Intelligence platform"
disable_service "com.apple.siri.context.service" "Siri context"
disable_service "com.apple.siriactionsd" "Siri actions"
disable_service "com.apple.siriknowledged" "Siri knowledge"
disable_service "com.apple.assistantd" "Assistant daemon"
disable_service "com.apple.siriinferenced" "Siri inference"
disable_service "com.apple.assistant_cdmd" "Assistant command"
disable_service "com.apple.sirittsd" "Siri text-to-speech"
disable_service "com.apple.proactived" "Proactive suggestions"
disable_service "com.apple.duetexpertd" "Duet expert system"
disable_service "com.apple.knowledge-agent" "Knowledge agent"
disable_service "com.apple.spotlightknowledged.updater" "Spotlight knowledge updater"
# macOS 27.2 additions discovered from the live gui launchd domain.
disable_service "com.apple.intelligencecontextd" "Intelligence context"
disable_service "com.apple.intelligenceflowd" "Intelligence flow"
disable_service "com.apple.intelligencetasksd" "Intelligence task scheduler"
disable_service "com.apple.knowledgeconstructiond" "Knowledge construction"
disable_service "com.apple.corespotlightd" "Core Spotlight"
disable_service "com.apple.corespotlightservice" "Core Spotlight service"
disable_service "com.apple.managedcorespotlightd" "Managed Core Spotlight"
disable_service "com.apple.spotlightknowledged" "Spotlight knowledge"
disable_service "com.apple.spotlightknowledged.importer" "Spotlight knowledge importer"
disable_service "com.apple.visualintelligenced" "Visual Intelligence"
disable_service "com.apple.visualintelligence.daemon-status" "Visual Intelligence status"
disable_service "com.apple.uiintelligencesupport.agent" "UI Intelligence support"
disable_service "com.apple.sirisuggestions" "Siri suggestions"
disable_service "com.apple.siriappintentsd" "Siri App Intents"
disable_service "com.apple.spotlightknowledged.updater.cachedelete" "Spotlight updater cache cleanup"
disable_service "com.apple.proactiveeventtrackerd" "Proactive event tracker"

# Telemetry & Analytics (3)
log_message "--- Disabling Telemetry & Analytics ---"
disable_service "com.apple.analyticsagent" "Analytics collection"
disable_service "com.apple.feedbackd" "Feedback daemon"
disable_service "com.apple.diagnostics_agent" "Diagnostics"

# Store & Media Services (4)
log_message "--- Disabling Store & Media Services ---"
disable_service "com.apple.appstoreagent" "App Store agent"
disable_service "com.apple.weatherd" "Weather service"
disable_service "com.apple.weather.menu" "Weather menu"
disable_service "com.apple.mediaremoteagent" "Media remote"

# Social & Communication (3)
log_message "--- Disabling Social & Communication ---"
disable_service "com.apple.sociallayerd" "Social framework"
disable_service "com.apple.keychainsharingmessagingd" "Keychain sharing"
log_message "🛡️  PRESERVED: com.apple.rapportd - Handoff/Continuity"

# Image analysis services are functional dependencies for Live Text/OCR.
log_message "--- Preserving Image Analysis Services ---"
log_message "🛡️  PRESERVED: mediaanalysisd and Visual Intelligence - Live Text/OCR"
log_message "🛡️  PRESERVED: Core Spotlight and metadata workers - searchable image text"
disable_service "com.apple.mediastream.mstreamd" "Media streaming"

# SYSTEM-LEVEL SERVICES (LaunchDaemons)
log_message "--- Checking System-Level Services by exact launchd name ---"
for service_entry in "${SYSTEM_SERVICES[@]}"; do
    IFS='|' read -r service_name service_description <<< "$service_entry"
    disable_system_service "$service_name" "$service_description"
done

# KILL RUNNING PROCESSES
log_message "--- Killing Running Bloat Processes ---"
kill_process "analyticsagent" "Analytics Agent"
kill_process "siriinferenced" "Siri Inference"
kill_process "siriactionsd" "Siri Actions"
kill_process "proactived" "Proactive Suggestions"
kill_process "intelligenceplatformd" "Apple Intelligence"
kill_process "intelligencecontextd" "Intelligence Context"
kill_process "intelligenceflowd" "Intelligence Flow"
kill_process "intelligencetasksd" "Intelligence Tasks"
kill_process "siriappintentsd" "Siri App Intents"
kill_process "siriknowledged" "Siri Knowledge"
kill_process "feedbackd" "Feedback Daemon"
kill_process "knowledge-agent" "Knowledge Agent"
kill_process "diagnostics_agent" "Diagnostics Agent"
kill_process "duetexpertd" "Duet Expert"
kill_process "sirittsd" "Siri TTS"
kill_process "wifianalyticsd" "WiFi Analytics"
kill_process "geoanalyticsd" "Geo Analytics"
kill_process "inputanalyticsd" "Input Analytics"
kill_process "analyticsd" "Analytics Daemon"
kill_process "audioanalyticsd" "Audio Analytics"
kill_process "ecosystemanalyticsd" "Ecosystem Analytics"
kill_process "osanalyticshelper" "OS Analytics Helper"
kill_process "proactiveeventtrackerd" "Proactive Event Tracker"

# iTunes/Music Related Processes
log_message "--- Killing iTunes/Music Related Processes ---"
kill_process "commerce" "iTunes Commerce"
kill_process "itunescloudd" "iTunes Cloud"
kill_process "mediaremoteagent" "Media Remote"
kill_process "Music" "Music App"
kill_process "com.apple.Music" "Music Service"

# Spotlight and image-analysis processes are deliberately preserved. They are
# used by Live Text/OCR, Quick Look and searchable text extraction from JPEGs.
log_message "--- Preserving Live Text/OCR and Image Indexing Processes ---"
for functional_process in "${FUNCTIONAL_PROTECTED_PROCESSES[@]}"; do
    log_message "🛡️  PRESERVED: $functional_process - Live Text/OCR and image indexing"
done

verify_processes() {
    local process_name
    local pids
    local process_checks=(
        analyticsagent siriactionsd
        proactived intelligenceplatformd intelligencecontextd intelligenceflowd
        intelligencetasksd siriappintentsd siriknowledged feedbackd
        knowledge-agent diagnostics_agent duetexpertd sirittsd
        wifianalyticsd ecosystemanalyticsd osanalyticshelper
        geoanalyticsd inputanalyticsd analyticsd audioanalyticsd
        proactiveeventtrackerd
    )

    sleep 2
    log_message "--- Verifying targeted processes after cleanup ---"
    for process_name in "${process_checks[@]}"; do
        pids=$(pgrep -x "$process_name" 2>/dev/null || true)
        if [ -n "$pids" ]; then
            log_message "⚠️  STILL RUNNING/RESPAWNED: $process_name (PIDs: $pids)"
            ((PROCESSES_RESPAWNED+=1))
        fi
    done
}

if [ "$MODE" != "dry-run" ] && [ "$MODE" != "user-only" ]; then
    verify_processes
fi

log_message "=== Summary ==="
log_message "Processes killed: $PROCESSES_KILLED"
log_message "Processes failed: $PROCESSES_FAILED"
log_message "Processes protected: $PROCESSES_SKIPPED"
log_message "Processes respawned/SIP-protected: $PROCESSES_RESPAWNED"
log_message "Services disabled: $SERVICES_DISABLED"
log_message "Services failed: $SERVICES_FAILED"
log_message "Services not found: $SERVICES_NOT_FOUND"
log_message "Services protected: $SERVICES_PROTECTED"
log_message "Services already disabled: $SERVICES_ALREADY_DISABLED"
log_message "Services re-enabled: $SERVICES_REENABLED"
log_message "Total service decisions: $((SERVICES_DISABLED + SERVICES_FAILED + SERVICES_NOT_FOUND + SERVICES_PROTECTED + SERVICES_ALREADY_DISABLED + SERVICES_REENABLED))"
RAM_AFTER_BYTES=$(memory_available_bytes)
TARGET_RSS_AFTER_KB=$(target_process_rss_kb)
log_message "📊 Available RAM after:  $(format_mb "$RAM_AFTER_BYTES")"
log_message "📈 RAM change:          $(format_mb "$((RAM_AFTER_BYTES - RAM_BEFORE_BYTES))")"
log_message "📈 Target RSS change:    $(format_mb "$(((TARGET_RSS_BEFORE_KB - TARGET_RSS_AFTER_KB) * 1024))")"
log_message "🛡️  System update protection: ENABLED"
log_message "=== Bloat Service Disabler Complete ==="

# Verify essential services are still running. A root LaunchDaemon must inspect
# the logged-in GUI domain, not gui/0 (which emits launchctl domain errors).
verify_essential_services() {
    local user_id
    local gui_services_output
    local found_gui=false

    log_message "--- Verifying Essential Services ---"
    while IFS= read -r user_id; do
        [ -n "$user_id" ] || continue
        found_gui=true
        gui_services_output=$(launchctl print "gui/$user_id" 2>/dev/null || true)
        if [[ "$gui_services_output" == *"com.apple.sharingd"* ]]; then
            log_message "✅ KEPT: gui/$user_id/com.apple.sharingd - AirDrop/Sharing (as requested)"
        else
            log_message "⚠️  WARNING: gui/$user_id/com.apple.sharingd not found"
        fi
        if [[ "$gui_services_output" == *"com.apple.exchange.exchangesyncd"* ]]; then
            log_message "✅ KEPT: gui/$user_id/com.apple.exchange.exchangesyncd - Exchange Sync (as requested)"
        else
            log_message "ℹ️  INFO: gui/$user_id/com.apple.exchange.exchangesyncd not found (may not be needed)"
        fi
    done < <(get_gui_uids | sort -u)
    if [ "$found_gui" = false ]; then
        log_message "ℹ️  INFO: no logged-in GUI domain found; essential-service check deferred"
    fi
}

verify_essential_services

exit 0
