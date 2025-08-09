#!/bin/bash

# macOS Bloat Service Disabler - Enhanced Version (System Update Safe)
# Disables 32+ unnecessary services while keeping essential ones
# Handles both user and system services + kills running processes
# UPDATED: Added system update protection and safer process handling
# Created: $(date)

set -euo pipefail

LOG_FILE="$HOME/Library/Logs/disable_bloat_services.log"
SCRIPT_PATH="${SCRIPT_PATH:-/usr/local/bin/disable_bloat_services.sh}"
# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
SERVICES_DISABLED=0
SERVICES_FAILED=0
PROCESSES_KILLED=0
PROCESSES_SKIPPED=0

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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Enhanced function to safely kill processes with system update protection
kill_process() {
    local process_name="$1"
    local description="$2"
    
    # Check if this process is protected
    for protected in "${SYSTEM_UPDATE_PROTECTED[@]}"; do
        if [[ "$process_name" == *"$protected"* ]] || [[ "$protected" == *"$process_name"* ]]; then
            log_message "🛡️  PROTECTED: $process_name - $description (System update critical)"
            ((PROCESSES_SKIPPED++))
            return 0
        fi
    done
    
    local pids=$(pgrep -f "$process_name" 2>/dev/null)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            # Double-check the actual process name to avoid false positives
            local actual_name=$(ps -p "$pid" -o comm= 2>/dev/null | xargs basename)
            
            # Additional protection check on actual process name
            local is_protected=false
            for protected in "${SYSTEM_UPDATE_PROTECTED[@]}"; do
                if [[ "$actual_name" == *"$protected"* ]] || [[ "$protected" == *"$actual_name"* ]]; then
                    log_message "🛡️  PROTECTED: $actual_name (PID: $pid) - System critical process"
                    ((PROCESSES_SKIPPED++))
                    is_protected=true
                    break
                fi
            done
            
            if [ "$is_protected" = false ]; then
                # Use SIGTERM first, then SIGKILL if needed (gentler approach)
                if kill -TERM "$pid" 2>/dev/null; then
                    sleep 1
                    # Check if process is still running
                    if kill -0 "$pid" 2>/dev/null; then
                        # Still running, use SIGKILL
                        if kill -9 "$pid" 2>/dev/null; then
                            log_message "💀 KILLED: $process_name (PID: $pid) - $description (SIGKILL)"
                            ((PROCESSES_KILLED++))
                        else
                            log_message "❌ FAILED TO KILL: $process_name (PID: $pid) - $description"
                        fi
                    else
                        log_message "✅ TERMINATED: $process_name (PID: $pid) - $description (SIGTERM)"
                        ((PROCESSES_KILLED++))
                    fi
                else
                    log_message "❌ FAILED TO TERMINATE: $process_name (PID: $pid) - $description"
                fi
            fi
        done
    fi
}

# Function to disable system-level services
disable_system_service() {
    local service_name="$1"
    local description="$2"
    
    if sudo launchctl print system 2>/dev/null | grep -q "$service_name" 2>/dev/null; then
        if sudo launchctl disable "system/$service_name" 2>/dev/null; then
            log_message "🔴 SYSTEM DISABLED: $service_name - $description"
            ((SERVICES_DISABLED++))
        else
            log_message "❌ SYSTEM FAILED: $service_name - $description"
            ((SERVICES_FAILED++))
        fi
    else
        log_message "ℹ️  SYSTEM NOT FOUND: $service_name - $description"
    fi
}

# Function to disable a service for all logged-in users
disable_service() {
    local service_name="$1"
    local description="$2"
    local disabled=false
    
    # Get all logged-in users
    for user_id in $(ps -axo uid,comm | grep loginwindow | awk '{print $1}' | sort -u || true); do
        if [[ "$user_id" =~ ^[0-9]+$ ]] && [ "$user_id" -ge 500 ]; then
            # Try to disable for this user
            if launchctl print "gui/$user_id" 2>/dev/null | grep -q "$service_name" 2>/dev/null; then
                if launchctl disable "gui/$user_id/$service_name" 2>/dev/null; then
                    log_message "✅ DISABLED: $service_name - $description (UID: $user_id)"
                    disabled=true
                    ((SERVICES_DISABLED++))
                else
                    log_message "❌ FAILED: $service_name - $description (UID: $user_id)"
                    ((SERVICES_FAILED++))
                fi
            fi
        fi
    done
    
    # Also try current user context if running as user
    if [ "$EUID" -ne 0 ]; then
        if launchctl print "gui/$(id -u)" 2>/dev/null | grep -q "$service_name" 2>/dev/null; then
            if launchctl disable "gui/$(id -u)/$service_name" 2>/dev/null; then
                log_message "✅ DISABLED: $service_name - $description (current user)"
                disabled=true
                ((SERVICES_DISABLED++))
            else
                log_message "❌ FAILED: $service_name - $description (current user)"
                ((SERVICES_FAILED++))
            fi
        fi
    fi
    
    if [ "$disabled" = false ]; then
        log_message "ℹ️  NOT FOUND: $service_name - $description"
    fi
}

# Function to check if system updates are currently running
check_system_updates() {
    # Check for actual active installation/update processes (not background daemons)
    local active_update_processes=("installer" "mas install" "pkgutil" "pkgbuild")
    
    for proc in "${active_update_processes[@]}"; do
        if pgrep -f "$proc" > /dev/null 2>&1; then
            local pids=$(pgrep -f "$proc")
            log_message "⚠️  ACTIVE UPDATE DETECTED: $proc (PIDs: $pids)"
            log_message "🛑 ABORTING: Will not run debloat service during active installations"
            log_message "💡 TIP: Try running again after installations complete"
            exit 0
        fi
    done
    
    # Check for active softwareupdate processes (not the background daemon)
    # Look for actual download/install activity
    if pgrep -f "softwareupdate.*-[id]" > /dev/null 2>&1; then
        local pids=$(pgrep -f "softwareupdate.*-[id]")
        log_message "⚠️  ACTIVE SOFTWARE UPDATE DETECTED: softwareupdate (PIDs: $pids)"
        log_message "🛑 ABORTING: Will not run debloat service during software updates"
        log_message "💡 TIP: Try running again after updates complete"
        exit 0
    fi
    
    # Check if macOS installer is running
    if pgrep -f "Install macOS" > /dev/null 2>&1 || pgrep -f "macOS.*Installer" > /dev/null 2>&1; then
        log_message "⚠️  macOS INSTALLER DETECTED - Aborting debloat service"
        exit 0
    fi
    
    # Check for high mobileassetd CPU usage (indicates active downloading)
    local mobileasset_cpu=$(ps -eo pid,pcpu,comm | grep mobileassetd | awk '{if($2 > 5.0) print $1}' | head -1 || true)
    if [ -n "$mobileasset_cpu" ]; then
        log_message "⚠️  HIGH MOBILEASSETD ACTIVITY DETECTED - Likely downloading updates"
        log_message "🛑 ABORTING: Will not run debloat service during asset downloads"
        log_message "💡 TIP: Try running again after downloads complete"
        exit 0
    fi
}

log_message "=== Starting macOS Bloat Service Disabler (System Update Safe) ==="
log_message "🔍 Checking for active system updates..."
check_system_updates
log_message "✅ No system updates detected - proceeding with debloat service"

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
disable_service "com.apple.rapportd" "Handoff/Continuity"

# Previously Disabled Media Services (2)
log_message "--- Disabling Media Services ---"
disable_service "com.apple.mediaanalysisd" "Media analysis"
disable_service "com.apple.mediastream.mstreamd" "Media streaming"

# SYSTEM-LEVEL SERVICES (LaunchDaemons) - Skipped in automated mode
log_message "--- System-Level Services (Skipping - No sudo in automated mode) ---"
log_message "ℹ️  System-level services require sudo and are skipped during automated runs"
log_message "💡 To disable system services, run the script manually: $SCRIPT_PATH"
# disable_system_service "com.apple.wifianalyticsd" "WiFi Analytics"
# disable_system_service "com.apple.icloud.findmydeviced" "Find My Device (System)"
# disable_system_service "com.apple.ecosystemanalyticsd" "Ecosystem Analytics"
# disable_system_service "com.apple.findmy.findmybeaconingd" "Find My Beaconing"
# disable_system_service "com.apple.diagnosticservicesd" "Diagnostic Services"
# disable_system_service "com.apple.osanalytics.osanalyticshelper" "OS Analytics Helper"
# disable_system_service "com.apple.findmymacd" "Find My Mac"
# disable_system_service "com.apple.findmymacmessenger" "Find My Mac Messenger"
# disable_system_service "com.apple.analyticsd" "Analytics Daemon"
# disable_system_service "com.apple.audioanalyticsd" "Audio Analytics"
# disable_system_service "com.apple.usbctelemetryd" "USB-C Telemetry"

# KILL RUNNING PROCESSES
log_message "--- Killing Running Bloat Processes ---"
kill_process "analyticsagent" "Analytics Agent"
kill_process "siriinferenced" "Siri Inference"
kill_process "siriactionsd" "Siri Actions"
kill_process "findmylocateagent" "Find My Location"
kill_process "findmydevice-user-agent" "Find My Device Agent"
kill_process "proactived" "Proactive Suggestions"
kill_process "intelligenceplatformd" "Apple Intelligence"
kill_process "feedbackd" "Feedback Daemon"
kill_process "knowledge-agent" "Knowledge Agent"
kill_process "diagnostics_agent" "Diagnostics Agent"
kill_process "duetexpertd" "Duet Expert"
kill_process "rapportd" "Handoff/Continuity"
kill_process "sirittsd" "Siri TTS"
kill_process "spotlightknowledged" "Spotlight Knowledge"
kill_process "wifianalyticsd" "WiFi Analytics"
kill_process "ecosystemanalyticsd" "Ecosystem Analytics"
kill_process "osanalyticshelper" "OS Analytics Helper"
kill_process "geoanalyticsd" "Geo Analytics"
kill_process "mediaanalysisd" "Media Analysis"
kill_process "inputanalyticsd" "Input Analytics"

# iTunes/Music Related Processes
log_message "--- Killing iTunes/Music Related Processes ---"
kill_process "commerce" "iTunes Commerce"
kill_process "itunescloudd" "iTunes Cloud"
kill_process "mediaremoteagent" "Media Remote"
kill_process "Music" "Music App"
kill_process "com.apple.Music" "Music Service"

# Spotlight Related Processes (if you want to reduce indexing)
log_message "--- Killing Spotlight Related Processes (Optional) ---"
kill_process "mdworker" "Spotlight Worker"
kill_process "mds_stores" "Spotlight Stores"
kill_process "corespotlightd" "Core Spotlight"
kill_process "managedcorespotlightd" "Managed Core Spotlight"

log_message "=== Summary ==="
log_message "Processes killed: $PROCESSES_KILLED"
log_message "Processes protected: $PROCESSES_SKIPPED"
log_message "Services disabled: $SERVICES_DISABLED"
log_message "Services failed: $SERVICES_FAILED"
log_message "Total services processed: $((SERVICES_DISABLED + SERVICES_FAILED))"
log_message "🛡️  System update protection: ENABLED"
log_message "=== Bloat Service Disabler Complete ==="

# Verify essential services are still running
log_message "--- Verifying Essential Services ---"
if launchctl print "gui/$(id -u)" | grep -q "com.apple.sharingd" 2>/dev/null; then
    log_message "✅ KEPT: com.apple.sharingd - AirDrop/Sharing (as requested)"
else
    log_message "⚠️  WARNING: com.apple.sharingd not found"
fi

if launchctl print "gui/$(id -u)" | grep -q "com.apple.exchange.exchangesyncd" 2>/dev/null; then
    log_message "✅ KEPT: com.apple.exchange.exchangesyncd - Exchange Sync (as requested)"
else
    log_message "ℹ️  INFO: com.apple.exchange.exchangesyncd not found (may not be needed)"
fi

exit 0
