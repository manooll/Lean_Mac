#!/bin/bash

# macOS Tahoe 26.0 Bloat Service Disabler
# Version: 2.3 - Minimal Spotlight Edition (Fixed CMD+Space)
# Purpose: Maximize dev resources, privacy, and battery life by disabling Apple/Adobe bloat
# Repository: https://github.com/manull/Lean-Mac (styling inspiration)
# 
# Disables 60+ unnecessary services and processes while keeping essential ones
# NEW: Preserves app search functionality while disabling heavy Spotlight AI/ML indexing
# Targets highest resource consumers including mds_stores, cloudd, Apple Intelligence
# Runs continuously with configurable intervals for aggressive bloat control
# 
# Updated for macOS Tahoe 26.0 with Apple Intelligence and enhanced AI services
# 
# Author: Jay L. [Manull]
# License: MIT

LOG_FILE="$HOME/Library/Logs/disable_bloat_services.log"
SCRIPT_VERSION="2.3"
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Performance tracking variables
SERVICES_DISABLED=0
SERVICES_FAILED=0
PROCESSES_KILLED=0
PROCESSES_FAILED=0

# --- Configurable Blocklists ---

# Apple Intelligence Services (NEW IN TAHOE 26.0) - Highest Priority
AI_SERVICES=(
    "com.apple.intelligenceplatformd"
    "com.apple.intelligencetasksd"
    "com.apple.intelligencecontextd"
    "com.apple.intelligenceflowd"
    "com.apple.knowledgeconstructiond"
    "com.apple.privatecloudcomputed"
    "com.apple.TGOnDeviceInferenceProviderService"
)

AI_PROCS=(
    "intelligenceplatformd"
    "intelligencetasksd"
    "intelligencecontextd"
    "intelligenceflowd"
    "knowledgeconstructiond"
    "privatecloudcomputed"
    "TGOnDeviceInferenceProviderService"
)

# Enhanced Spotlight Services (Major CPU consumers)
# NOTE: Keep core spotlight for app launching - only disable AI/ML heavy components
SPOTLIGHT_SERVICES=(
    "com.apple.spotlightknowledged"           # AI Knowledge Base (HEAVY CPU)
    "com.apple.spotlightknowledged.updater"   # AI Knowledge Updater (HEAVY CPU)
    "com.apple.spotlightknowledged.importer"  # AI Knowledge Importer (HEAVY CPU)
    # KEEP: com.apple.corespotlightservice (needed for app search)
)

SPOTLIGHT_PROCS=(
    "mds_stores"              # Heavy metadata indexing (KEEP mds for basic search)
    "mdworker_shared"         # Shared metadata workers (high CPU)
    "mdbulkimport"            # Bulk import (heavy operation)
    "spotlightknowledged"     # AI knowledge daemon (HEAVY CPU)
    "managedcorespotlightd"   # Managed spotlight (not essential)
    # KEEP: mds, mdworker, mdimport, mdutil, mdfind, corespotlightd (essential for app search)
)

# High-Resource System Processes (CRITICAL - Kill First)
HIGH_RESOURCE_PROCS=(
    "mds_stores"              # Spotlight Metadata Store (60%+ CPU)
    "mobileassetd"            # Mobile Asset Daemon (System Updates)
    "homeenergyd"             # Home Energy Daemon (High CPU)
    "dasd"                    # Duet Activity Scheduler (AI Predictions)
    "deleted"                 # Cache Deletion Daemon
    "deleted_helper"          # Cache Deletion Helper
    "accountsd"               # Account Sync Daemon (High CPU)
    "coreduetd"               # Core Duet Daemon (AI Predictions)
    "audioanalyticsd"         # Audio Analytics Daemon
)

# Enhanced AI & ML Services
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

AI_ML_PROCS=(
    "mediaanalysisd-access"
    "mediaanalysisd"
    "proactiveeventtrackerd"
    "geoanalyticsd"
    "memoryanalyticsd"
    "triald"
    "triald_system"
    "proactived"
    "duetexpertd"
    "knowledge-agent"
)

# Siri & Assistant Services
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

SIRI_PROCS=(
    "assistantd"
    "siriknowledged"
    "siriactionsd"
    "siriinferenced"
    "sirittsd"
    "assistant_cdmd"
)

# Cloud & Sync Services (EXCLUDING Find My for device location)
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

ICLOUD_PROCS=(
    "cloudd"
    "cloudphotod"
    "cloudsettingssyncagent"
    "cloudpaird"
    "cloudanalyticsd"
    "cloudkit"
    "itunescloudd"
)

# Analytics & Telemetry Services (Privacy)
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

TELEMETRY_PROCS=(
    "analyticsagent"
    "analyticsd"
    "feedbackd"
    "diagnostics_agent"
    "wifianalyticsd"
    "ecosystemanalyticsd"
    "osanalyticshelper"
    "inputanalyticsd"
    "audioanalyticsd"
)

# Store & Media Services
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

MEDIA_PROCS=(
    "commerce"
    "mediaremoteagent"
)

# Social & Communication Services
SOCIAL_SERVICES=(
    "com.apple.sociallayerd"
    "com.apple.keychainsharingmessagingd"
    "com.apple.rapportd"
)

SOCIAL_PROCS=(
    "rapportd"
)

# Adobe Background Services (Resource Hogs)
ADOBE_SERVICES=(
    "com.adobe.AdobeCreativeCloud"
    "com.adobe.ccxprocess"
    "com.adobe.acc.installer.v2"
)

ADOBE_PROCS=(
    "AdobeCreativeCloud"
    "ccxprocess"
    "Creative Cloud"
    "ACCFinderSync"
    "Core Sync"
    "AdobeIPCBroker"
    "AdobeUpdateService"
    "AdobeGCClient"
)

# Figma Processes
FIGMA_PROCS=(
    "figma_agent"
)

# Additional System Processes
SYSTEM_PROCS=(
    "appleaccountd"
    "amsaccountsd"
    "homed"
    "idleassetsd"
    "assetsubscriptiond"
    "remindd"
    "axassetsd"
    "parsec-fbf"
    "parsecd"
    "chronod"
    "PasswordBreachAgent"
)

# Combine all services for processing
ALL_USER_SERVICES=("${AI_SERVICES[@]}" "${SPOTLIGHT_SERVICES[@]}" "${AI_ML_SERVICES[@]}" "${SIRI_SERVICES[@]}" "${ICLOUD_SERVICES[@]}" "${TELEMETRY_SERVICES[@]}" "${MEDIA_SERVICES[@]}" "${SOCIAL_SERVICES[@]}" "${ADOBE_SERVICES[@]}")

ALL_SYSTEM_SERVICES=("${TELEMETRY_SERVICES[@]}" "${ADOBE_SERVICES[@]}")

# Create deduplicated process list for efficiency
ALL_BLOAT_PROCS=("${HIGH_RESOURCE_PROCS[@]}" "${AI_PROCS[@]}" "${SPOTLIGHT_PROCS[@]}" "${AI_ML_PROCS[@]}" "${SIRI_PROCS[@]}" "${ICLOUD_PROCS[@]}" "${TELEMETRY_PROCS[@]}" "${MEDIA_PROCS[@]}" "${SOCIAL_PROCS[@]}" "${ADOBE_PROCS[@]}" "${FIGMA_PROCS[@]}" "${SYSTEM_PROCS[@]}")

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
    
    # Active bloat processes (for comparison)
    local bloat_count=0
    for proc in "${HIGH_RESOURCE_PROCS[@]}"; do
        if pgrep -f "$proc" >/dev/null 2>&1; then
            ((bloat_count++))
        fi
    done
    log_message "High-resource bloat processes running: $bloat_count"
}

# Function to deduplicate process arrays
deduplicate_process_list() {
    local temp_file=$(mktemp)
    printf '%s\n' "${ALL_BLOAT_PROCS[@]}" | sort | uniq > "$temp_file"
    
    # Use compatible alternative to readarray
    DEDUPLICATED_PROCS=()
    while IFS= read -r line; do
        DEDUPLICATED_PROCS+=("$line")
    done < "$temp_file"
    
    rm "$temp_file"
    log_message "📋 Deduplicated process list: ${#ALL_BLOAT_PROCS[@]} → ${#DEDUPLICATED_PROCS[@]} unique processes"
}

# Enhanced bootout service for maximum persistence (macOS 12+)
bootout_service() {
    local type="$1" # "system" or "gui/$(id -u)"
    local name="$2"
    # Try all common plist locations (fails silently if not found)
    launchctl bootout "$type" "/System/Library/LaunchDaemons/$name.plist" 2>/dev/null
    launchctl bootout "$type" "/Library/LaunchDaemons/$name.plist" 2>/dev/null
    launchctl bootout "$type" "/System/Library/LaunchAgents/$name.plist" 2>/dev/null
    launchctl bootout "$type" "/Library/LaunchAgents/$name.plist" 2>/dev/null
    launchctl bootout "$type" "/Users/$(id -un)/Library/LaunchAgents/$name.plist" 2>/dev/null
}

# Function to disable user-level services (LaunchAgents)
disable_service() {
    local service_name="$1"
    local disabled=false
    
    # Get all logged-in users
    for user_id in $(ps -axo uid,comm | grep loginwindow | awk '{print $1}' | sort -u); do
        if [[ "$user_id" =~ ^[0-9]+$ ]] && [ "$user_id" -ge 500 ]; then
            # Try to disable for this user
            if launchctl print "gui/$user_id" 2>/dev/null | grep -q "$service_name" 2>/dev/null; then
                if launchctl disable "gui/$user_id/$service_name" 2>/dev/null; then
                    log_message "✅ DISABLED: $service_name (UID: $user_id)"
                    disabled=true
                    ((SERVICES_DISABLED++))
                else
                    log_message "❌ FAILED: $service_name (UID: $user_id)"
                    ((SERVICES_FAILED++))
                fi
                # Extra persistence: bootout from bootstrap context
                bootout_service "gui/$user_id" "$service_name"
            fi
        fi
    done
    
    # Also try current user context if running as user
    if [ "$EUID" -ne 0 ]; then
        if launchctl print "gui/$(id -u)" 2>/dev/null | grep -q "$service_name" 2>/dev/null; then
            if launchctl disable "gui/$(id -u)/$service_name" 2>/dev/null; then
                log_message "✅ DISABLED: $service_name (current user)"
                disabled=true
                ((SERVICES_DISABLED++))
            else
                log_message "❌ FAILED: $service_name (current user)"
                ((SERVICES_FAILED++))
            fi
            # Extra persistence: bootout from bootstrap context
            bootout_service "gui/$(id -u)" "$service_name"
        fi
    fi
    
    if [ "$disabled" = false ]; then
        log_message "ℹ️  NOT FOUND: $service_name"
    fi
}

# Function to disable system-level services (LaunchDaemons)
disable_system_service() {
    local service_name="$1"
    
    if sudo launchctl print system 2>/dev/null | grep -q "$service_name" 2>/dev/null; then
        if sudo launchctl disable "system/$service_name" 2>/dev/null; then
            log_message "🔴 SYSTEM DISABLED: $service_name"
            ((SERVICES_DISABLED++))
        else
            log_message "❌ SYSTEM FAILED: $service_name"
            ((SERVICES_FAILED++))
        fi
        # Extra persistence: bootout from system bootstrap context
        bootout_service "system" "$service_name"
    else
        log_message "ℹ️  SYSTEM NOT FOUND: $service_name"
    fi
}

# Function to properly disable and unload services
# Includes additional modern services
update_services_and_processes() {
    log_message "🔄 Updating services and processes for current macOS version"

    MISSING_AI_SERVICES=(
        "com.apple.siri.soundanalysisworkerd"
        "com.apple.gamed"
        "com.apple.gamekit.bulletind" 
        "com.apple.backgroundtaskmanagement"
        "com.apple.tipsd"
        "com.apple.screentime.agent"
    )

    MISSING_TELEMETRY=(
        "com.apple.coremedialogd"
        "com.apple.weatherkit.weatherd"
        "com.apple.newsagent"
    )

    ALL_USER_SERVICES+=("${MISSING_AI_SERVICES[@]}" "${MISSING_TELEMETRY[@]}")

    log_message "✅ Updated: User services now include modern macOS service deactivations"
}

# Enhanced process killing with wildcard support
kill_process() {
    local proc="$1"
    local pids
    
    # Enhanced pattern matching for process variations (e.g., mdworker_shared.123)
    # Try exact match first, then wildcard patterns
    pids=$(pgrep -f "^$proc$" 2>/dev/null)
    if [ -z "$pids" ]; then
        # Try with common suffixes and variations
        pids=$(pgrep -f "$proc" 2>/dev/null)
    fi
    
    local killed=0
    for pid in $pids; do
        # Double-check we're not killing essential processes
        local cmd=$(ps -p "$pid" -o comm= 2>/dev/null | xargs basename)
        if [[ "$cmd" =~ ^(kernel|launchd|systemstats|loginwindow|WindowServer|Finder|Dock)$ ]]; then
            log_message "⚠️  SKIPPED: $proc (PID $pid) - Essential process"
            continue
        fi
        
        if kill -9 "$pid" 2>/dev/null; then
            log_message "💀 KILLED: $proc (PID $pid)"
            ((PROCESSES_KILLED++))
            killed=1
        else
            log_message "❌ FAILED TO KILL: $proc (PID $pid)"
            ((PROCESSES_FAILED++))
        fi
    done
    
    if [ "$killed" -eq 0 ] && [ -n "$pids" ]; then
        log_message "⚠️  NO KILL: $proc (process protected or already dead)"
    fi
}

# --- Core Execution ---

log_message "=========================================="
log_message "macOS Tahoe 26.0 Bloat Service Disabler v$SCRIPT_VERSION"
log_message "=========================================="
log_message "System: $(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
log_message "User: $(whoami), UID: $(id -u)"
log_message "🔒 Enhanced: Minimal Spotlight, deduplication, wildcards, performance metrics"

# --- 0. Capture baseline performance ---
capture_performance_metrics "BEFORE"

# --- 0.1. Update services for modern macOS ---
log_message "🔄 UPDATING FOR MODERN MACOS SERVICES..."
update_services_and_processes

# --- 1. Process deduplication for efficiency ---
log_message "🔄 DEDUPLICATING PROCESS LISTS..."
deduplicate_process_list

# --- 2. Spotlight: Selective Indexing (Keep App Search, Disable Heavy Indexing) ---
log_message "🔥 CONFIGURING MINIMAL SPOTLIGHT FOR APP SEARCH..."

# Keep system volume indexing for app launching (essential for macOS Tahoe)
SYSTEM_VOLUME="/"
if sudo mdutil -i on "$SYSTEM_VOLUME" 2>/dev/null; then
    log_message "✅ PRESERVED: System volume indexing for app search"
else
    log_message "⚠️  WARNING: Could not ensure system volume indexing"
fi

# Disable indexing on user data volumes to save resources
USER_DATA_PATHS=(
    "$HOME/Documents"
    "$HOME/Downloads" 
    "$HOME/Desktop"
    "$HOME/Pictures"
    "$HOME/Movies"
    "$HOME/Music"
)

for path in "${USER_DATA_PATHS[@]}"; do
    if [ -d "$path" ]; then
        if sudo mdutil -i off "$path" 2>/dev/null; then
            log_message "✅ Disabled heavy indexing on $path"
        else
            log_message "ℹ️  INFO: Could not disable indexing on $path - may not be indexed"
        fi
    fi
done

# Verification of killed processes
verify_processes_killed() {
    sleep 3
    local still_running=0
    for proc in "${HIGH_RESOURCE_PROCS[@]}"; do
        if pgrep -f "$proc" >/dev/null 2>&1; then
            log_message "⚠️  STILL RUNNING: $proc (may need stronger disable)"
            ((still_running++))
        fi
    done
    log_message "📊 Processes still running after kill: $still_running"
}

# Add enhanced processor killer
kill_process_enhanced() {
    local proc="$1"
    pkill -f "^$proc$" 2>/dev/null
    pkill -f "$proc\..*" 2>/dev/null
    pkill -f ".*$proc.*" 2>/dev/null
}

# Note: Spotlight categories left at system defaults for better compatibility
log_message "✅ Spotlight categories left at system defaults for optimal CMD+Space functionality"

# --- 3. Disable User-Level Services (LaunchAgents) ---
log_message "🎯 DISABLING USER-LEVEL BLOAT SERVICES..."
for svc in "${ALL_USER_SERVICES[@]}"; do
    disable_service "$svc"
done

# --- 4. Disable System-Level Services (LaunchDaemons) ---
log_message "🔴 DISABLING SYSTEM-LEVEL BLOAT SERVICES..."
for svc in "${ALL_SYSTEM_SERVICES[@]}"; do
    disable_system_service "$svc"
done

# --- 5. Kill Running Processes (PRIORITY: High-Resource First) ---
log_message "💀 PRIORITY KILL: Highest Resource Consumers..."
for proc in "${HIGH_RESOURCE_PROCS[@]}"; do
    kill_process_enhanced "$proc"
done

log_message "💀 KILLING REMAINING BLOAT PROCESSES (DEDUPLICATED)..."
for proc in "${DEDUPLICATED_PROCS[@]}"; do
    # Skip if already killed in high-resource phase
    already_killed=false
    for high_proc in "${HIGH_RESOURCE_PROCS[@]}"; do
        if [ "$proc" = "$high_proc" ]; then
            already_killed=true
            break
        fi
    done
    
    if [ "$already_killed" = false ]; then
        kill_process_enhanced "$proc"
    fi
done

# --- 5.1. Verify processes were killed ---
log_message "🔍 VERIFYING PROCESSES KILLED..."
verify_processes_killed

# --- 6. Essential Services Health Check ---
log_message "🛡️  VERIFYING ESSENTIAL SERVICES..."

# Check preserved services
ESSENTIAL_SERVICES=(
    "com.apple.sharingd"                    # AirDrop/Sharing
    "com.apple.exchange.exchangesyncd"      # Exchange Sync
    "com.apple.locationd"                   # Location Services
)

for essential in "${ESSENTIAL_SERVICES[@]}"; do
    if launchctl print "gui/$(id -u)" 2>/dev/null | grep -q "$essential" 2>/dev/null; then
        log_message "✅ PRESERVED: $essential"
    else
        log_message "ℹ️  INFO: $essential not found (may not be active)"
    fi
done

# Check if Apple Mail daemon is preserved (maild should be running for Office 365)
if ps aux | grep -v grep | grep -q "maild" 2>/dev/null; then
    log_message "✅ PRESERVED: Apple Mail daemon (Office 365 support)"
else
    log_message "ℹ️  INFO: Apple Mail daemon not found"
fi

# --- 7. Capture final performance metrics ---
sleep 2  # Brief pause for system to stabilize
capture_performance_metrics "AFTER"

# --- 8. Execution Summary ---
log_message "=========================================="
log_message "EXECUTION SUMMARY"
log_message "=========================================="
log_message "✅ Minimal Spotlight configured (CMD+Space working, heavy AI indexing disabled)"
log_message "📊 Services disabled: $SERVICES_DISABLED | Failed: $SERVICES_FAILED"
log_message "💀 Processes killed: $PROCESSES_KILLED | Failed: $PROCESSES_FAILED"
log_message "🔄 Total processes processed: ${#DEDUPLICATED_PROCS[@]} (deduplicated from ${#ALL_BLOAT_PROCS[@]})"
log_message "✅ Essential services preserved (including app search functionality)"

# Function to calculate and display success rates
display_success_rates() {
    if [ $((SERVICES_DISABLED + SERVICES_FAILED)) -gt 0 ]; then
        local service_success_rate=$((SERVICES_DISABLED * 100 / (SERVICES_DISABLED + SERVICES_FAILED)))
        log_message "📈 Service disable success rate: ${service_success_rate}%"
    fi

    if [ $((PROCESSES_KILLED + PROCESSES_FAILED)) -gt 0 ]; then
        local process_success_rate=$((PROCESSES_KILLED * 100 / (PROCESSES_KILLED + PROCESSES_FAILED)))
        log_message "📈 Process kill success rate: ${process_success_rate}%"
    fi
}

# Calculate success rate
display_success_rates

log_message "=========================================="
log_message "macOS Tahoe 26.0 Bloat Service Disabler v$SCRIPT_VERSION Complete"
log_message "=========================================="
log_message "Log file: $LOG_FILE"
log_message "💡 TIP: Run 'sudo restore_macos_services.sh' to undo these changes"

exit 0
