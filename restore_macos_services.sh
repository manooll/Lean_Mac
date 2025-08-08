#!/bin/bash

# macOS Tahoe 26.0 Service Restore Script
# Version: 1.0 - Companion to Bloat Service Disabler
# Purpose: Restore all services and functionality disabled by the bloat disabler
# 
# This script will:
# - Re-enable all disabled services
# - Restore Spotlight indexing
# - Provide system health verification
# 
# Author: Jay L. [Manull]
# License: MIT
# Repository: https://github.com/manooll/Lean_Mac

LOG_FILE="$HOME/Library/Logs/restore_macos_services.log"
# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
SCRIPT_VERSION="1.0"
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Performance tracking variables
SERVICES_ENABLED=0
SERVICES_FAILED=0

# Same service lists as the bloat disabler (for restoration)
AI_SERVICES=(
    "com.apple.intelligenceplatformd"
    "com.apple.intelligencetasksd"
    "com.apple.intelligencecontextd"
    "com.apple.intelligenceflowd"
    "com.apple.knowledgeconstructiond"
    "com.apple.privatecloudcomputed"
    "com.apple.TGOnDeviceInferenceProviderService"
)

SPOTLIGHT_SERVICES=(
    "com.apple.corespotlightservice"
    "com.apple.spotlightknowledged"
    "com.apple.spotlightknowledged.updater"
    "com.apple.spotlightknowledged.importer"
)

AI_ML_SERVICES=(
    "com.apple.mediaanalysisd-access"
    "com.apple.proactiveeventtrackerd"
    "com.apple.geoanalyticsd"
    "com.apple.memoryanalyticsd"
    "com.apple.inputanalyticsd"
    "com.apple.proactived"
    "com.apple.duetexpertd"
    "com.apple.knowledge-agent"
)

SIRI_SERVICES=(
    "com.apple.siri.context.service"
    "com.apple.siriactionsd"
    "com.apple.siriknowledged"
    "com.apple.assistantd"
    "com.apple.siriinferenced"
    "com.apple.assistant_cdmd"
    "com.apple.assistant_service"
    "com.apple.sirittsd"
)

ICLOUD_SERVICES=(
    "com.apple.cloudd"
    "com.apple.cloudphotod"
    "com.apple.icloud.searchpartyuseragent"
    "com.apple.protectedcloudstorage.protectedcloudkeysyncing"
    "com.apple.icloudmailagent"
    "com.apple.itunescloudd"
    "com.apple.syncdefaultsd"
    "com.apple.cloudsettingssyncagent"
)

TELEMETRY_SERVICES=(
    "com.apple.analyticsagent"
    "com.apple.feedbackd"
    "com.apple.diagnostics_agent"
    "com.apple.analyticsd"
    "com.apple.wifianalyticsd"
    "com.apple.ecosystemanalyticsd"
    "com.apple.diagnosticservicesd"
    "com.apple.osanalytics.osanalyticshelper"
    "com.apple.audioanalyticsd"
    "com.apple.usbctelemetryd"
)

MEDIA_SERVICES=(
    "com.apple.appstoreagent"
    "com.apple.weatherd"
    "com.apple.weather.menu"
    "com.apple.mediaremoteagent"
    "com.apple.mediaanalysisd"
    "com.apple.mediastream.mstreamd"
    "com.apple.amp.mediasharingd"
    "com.apple.mediacontinuityd"
)

SOCIAL_SERVICES=(
    "com.apple.sociallayerd"
    "com.apple.keychainsharingmessagingd"
    "com.apple.rapportd"
)

ADOBE_SERVICES=(
    "com.adobe.AdobeCreativeCloud"
    "com.adobe.ccxprocess"
    "com.adobe.acc.installer.v2"
)

# Combine all services for restoration
ALL_USER_SERVICES=("${AI_SERVICES[@]}" "${SPOTLIGHT_SERVICES[@]}" "${AI_ML_SERVICES[@]}" "${SIRI_SERVICES[@]}" "${ICLOUD_SERVICES[@]}" "${TELEMETRY_SERVICES[@]}" "${MEDIA_SERVICES[@]}" "${SOCIAL_SERVICES[@]}" "${ADOBE_SERVICES[@]}")

ALL_SYSTEM_SERVICES=("${TELEMETRY_SERVICES[@]}" "${ADOBE_SERVICES[@]}")

# --- Utility Functions ---

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to capture system performance metrics
capture_performance_metrics() {
    local label="$1"
    log_message "📊 PERFORMANCE METRICS ($label):"
    
    # CPU usage snapshot
    local cpu_usage=$(top -l 1 -s 0 | grep "CPU usage" | head -1)
    log_message "CPU: $cpu_usage"
    
    # Memory usage
    local memory_info=$(vm_stat | head -5 | tr '\n' ' ')
    log_message "Memory: $memory_info"
    
    # Process count
    local proc_count=$(ps aux | wc -l)
    log_message "Process count: $proc_count"
    
    # Disk space
    local disk_usage=$(df -h / | tail -1 | awk '{print "Used: "$3" Available: "$4" ("$5" full)"}')
    log_message "Disk: $disk_usage"
}

# Function to enable user-level services
enable_service() {
    local service_name="$1"
    local enabled=false
    
    # Get all logged-in users
    for user_id in $(ps -axo uid,comm | grep loginwindow | awk '{print $1}' | sort -u); do
        if [[ "$user_id" =~ ^[0-9]+$ ]] && [ "$user_id" -ge 500 ]; then
            # Try to enable for this user
            if launchctl enable "gui/$user_id/$service_name" 2>/dev/null; then
                log_message "✅ ENABLED: $service_name (UID: $user_id)"
                enabled=true
                ((SERVICES_ENABLED++))
            else
                log_message "❌ FAILED TO ENABLE: $service_name (UID: $user_id)"
                ((SERVICES_FAILED++))
            fi
        fi
    done
    
    # Also try current user context if running as user
    if [ "$EUID" -ne 0 ]; then
        if launchctl enable "gui/$(id -u)/$service_name" 2>/dev/null; then
            log_message "✅ ENABLED: $service_name (current user)"
            enabled=true
            ((SERVICES_ENABLED++))
        else
            log_message "❌ FAILED TO ENABLE: $service_name (current user)"
            ((SERVICES_FAILED++))
        fi
    fi
    
    if [ "$enabled" = false ]; then
        log_message "ℹ️  NOT FOUND OR ALREADY ENABLED: $service_name"
    fi
}

# Function to enable system-level services
enable_system_service() {
    local service_name="$1"
    
    if sudo launchctl enable "system/$service_name" 2>/dev/null; then
        log_message "🟢 SYSTEM ENABLED: $service_name"
        ((SERVICES_ENABLED++))
    else
        log_message "❌ SYSTEM FAILED TO ENABLE: $service_name"
        ((SERVICES_FAILED++))
    fi
}

# Function to verify user really wants to restore
confirm_restore() {
    echo
    echo "=========================================="
    echo "⚠️  macOS Service Restoration Warning"
    echo "=========================================="
    echo
    echo "This script will RESTORE all services disabled by the bloat disabler:"
    echo "• Re-enable Apple Intelligence services"
    echo "• Re-enable Spotlight indexing (will consume CPU/disk for hours)"
    echo "• Re-enable analytics and telemetry services"
    echo "• Re-enable cloud sync services"
    echo "• Re-enable Siri and assistant services"
    echo "• Re-enable media analysis services"
    echo
    echo "⚠️  WARNING: This will restore the 'bloat' and may impact performance!"
    echo
    read -p "Are you sure you want to proceed? (type 'RESTORE' to confirm): " confirm
    
    if [ "$confirm" != "RESTORE" ]; then
        log_message "❌ Restoration cancelled by user"
        echo "Restoration cancelled. No changes made."
        exit 0
    fi
}

# Function to stop bloat disabler services first
stop_bloat_disabler() {
    log_message "🛑 STOPPING BLOAT DISABLER SERVICES..."
    
    # Stop system daemon
    if sudo launchctl unload /Library/LaunchDaemons/com.user.disablebloatservices.plist 2>/dev/null; then
        log_message "✅ Stopped system bloat disabler daemon"
    else
        log_message "ℹ️  System bloat disabler daemon not running"
    fi
    
    # Stop user agent
    if launchctl unload ~/Library/LaunchAgents/com.user.disablebloatservices.agent.plist 2>/dev/null; then
        log_message "✅ Stopped user bloat disabler agent"
    else
        log_message "ℹ️  User bloat disabler agent not running"
    fi
    
    # Kill any running bloat disabler processes
    local pids=$(pgrep -f "disable_bloat_services" 2>/dev/null)
    for pid in $pids; do
        if kill -9 "$pid" 2>/dev/null; then
            log_message "💀 Killed bloat disabler process (PID: $pid)"
        fi
    done
}

# --- Core Execution ---

log_message "=========================================="
log_message "macOS Tahoe 26.0 Service Restoration v$SCRIPT_VERSION"
log_message "=========================================="
log_message "System: $(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
log_message "User: $(whoami), UID: $(id -u)"

# Check if running with appropriate privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script requires sudo privileges to restore system services."
    echo "Please run: sudo $0"
    exit 1
fi

# Confirm user really wants to restore
confirm_restore

# Capture baseline performance
capture_performance_metrics "BEFORE RESTORATION"

# --- 1. Stop bloat disabler first ---
stop_bloat_disabler

# --- 2. Restore Spotlight indexing ---
log_message "🔍 RESTORING SPOTLIGHT INDEXING ON ALL VOLUMES..."
for vol in $(mdutil -sa 2>/dev/null | awk -F ':' '{print $1}'); do
    if mdutil -i on "$vol" 2>/dev/null; then
        log_message "✅ Enabled indexing on $vol"
    else
        log_message "❌ Failed to enable indexing on $vol"
    fi
done

# --- 3. Enable User-Level Services ---
log_message "🟢 ENABLING USER-LEVEL SERVICES..."
for svc in "${ALL_USER_SERVICES[@]}"; do
    enable_service "$svc"
done

# --- 4. Enable System-Level Services ---
log_message "🟢 ENABLING SYSTEM-LEVEL SERVICES..."
for svc in "${ALL_SYSTEM_SERVICES[@]}"; do
    enable_system_service "$svc"
done

# --- 5. Restart essential services that might need it ---
log_message "🔄 RESTARTING KEY SERVICES..."

# Restart Spotlight
if sudo launchctl kickstart -k system/com.apple.metadata.mds 2>/dev/null; then
    log_message "✅ Restarted Spotlight metadata service"
fi

# Restart some key user services
key_services=("com.apple.cloudd" "com.apple.assistantd" "com.apple.corespotlightservice")
for svc in "${key_services[@]}"; do
    if launchctl kickstart -k "gui/$(id -u)/$svc" 2>/dev/null; then
        log_message "✅ Restarted $svc"
    fi
done

# --- 6. System health verification ---
log_message "🔍 VERIFYING RESTORED SERVICES..."

# Check some key services are now enabled
check_services=("com.apple.assistantd" "com.apple.cloudd" "com.apple.corespotlightservice" "com.apple.analyticsagent")
enabled_count=0

for svc in "${check_services[@]}"; do
    if launchctl print "gui/$(id -u)" 2>/dev/null | grep -q "$svc" 2>/dev/null; then
        log_message "✅ VERIFIED: $svc is enabled"
        ((enabled_count++))
    else
        log_message "⚠️  NOT VERIFIED: $svc may not be enabled"
    fi
done

# --- 7. Final performance metrics ---
sleep 3  # Allow services to start
capture_performance_metrics "AFTER RESTORATION"

# --- 8. Restoration Summary ---
log_message "=========================================="
log_message "RESTORATION SUMMARY"
log_message "=========================================="
log_message "🟢 Services enabled: $SERVICES_ENABLED | Failed: $SERVICES_FAILED"
log_message "✅ Spotlight indexing restored on all volumes"
log_message "🔍 Key services verified: $enabled_count/$(echo ${#check_services[@]})"

# Calculate success rate
if [ $((SERVICES_ENABLED + SERVICES_FAILED)) -gt 0 ]; then
    local success_rate=$((SERVICES_ENABLED * 100 / (SERVICES_ENABLED + SERVICES_FAILED)))
    log_message "📈 Service restoration success rate: ${success_rate}%"
fi

log_message "=========================================="
log_message "⚠️  IMPORTANT POST-RESTORATION NOTES"
log_message "=========================================="
log_message "🔍 Spotlight will now re-index all volumes (may take hours)"
log_message "📊 Analytics and telemetry services are restored"
log_message "☁️  iCloud sync services are restored"
log_message "🤖 Apple Intelligence services are restored"
log_message "🔄 System restart recommended for full restoration"
log_message ""
log_message "💡 TIP: Monitor Activity Monitor for CPU usage during Spotlight re-indexing"
log_message "💡 TIP: You can re-run the bloat disabler anytime: sudo disable_bloat_services.sh"

log_message "=========================================="
log_message "macOS Service Restoration v$SCRIPT_VERSION Complete"
log_message "=========================================="
log_message "Log file: $LOG_FILE"

echo
echo "✅ Restoration complete! System restart recommended."
echo "📝 Check log file: $LOG_FILE"

exit 0 