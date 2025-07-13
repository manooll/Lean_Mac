#!/bin/bash

# macOS Tahoe 26.0 Cache Cleanup Script
# Version: 2.1 - Enhanced for Apple Intelligence and new system caches
# Updated for macOS Tahoe 26.0
# Author: Jay L. [Manull]
# License: MIT
# Repository: https://github.com/manull/lean_macos

LOG_FILE="$HOME/Library/Logs/cache_cleanup.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to safely remove directory contents
safe_remove() {
    local dir="$1"
    local description="$2"
    
    if [ -d "$dir" ]; then
        local size_before=$(du -sh "$dir" 2>/dev/null | cut -f1)
        rm -rf "$dir"/* 2>/dev/null
        local size_after=$(du -sh "$dir" 2>/dev/null | cut -f1)
        log_message "🧹 CLEANED: $description ($dir) - Was: $size_before, Now: $size_after"
    else
        log_message "ℹ️  NOT FOUND: $description ($dir)"
    fi
}

log_message "=== Starting macOS Tahoe 26.0 Cache Cleanup ==="
log_message "System: $(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"

# Stop bloat services first
log_message "🛑 Stopping bloat services before cleanup..."
sudo launchctl unload /Library/LaunchDaemons/com.user.disablebloatservices.plist 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.user.disablebloatservices.agent.plist 2>/dev/null || true

# Apple Intelligence Caches (NEW IN TAHOE 26.0)
log_message "--- Cleaning Apple Intelligence Caches ---"
safe_remove "$HOME/Library/Caches/com.apple.intelligenceplatformd" "Apple Intelligence Platform Cache"
safe_remove "$HOME/Library/Caches/com.apple.intelligencetasksd" "Apple Intelligence Tasks Cache"
safe_remove "$HOME/Library/Caches/com.apple.intelligencecontextd" "Apple Intelligence Context Cache"
safe_remove "$HOME/Library/Caches/com.apple.knowledgeconstructiond" "Knowledge Construction Cache"
safe_remove "$HOME/Library/Caches/com.apple.privatecloudcomputed" "Private Cloud Compute Cache"

# Enhanced AI/ML Caches
log_message "--- Cleaning AI/ML Caches ---"
safe_remove "$HOME/Library/Caches/com.apple.mediaanalysisd" "Media Analysis Cache"
safe_remove "$HOME/Library/Caches/com.apple.proactiveeventtrackerd" "Proactive Event Tracker Cache"
safe_remove "$HOME/Library/Caches/com.apple.geoanalyticsd" "Geographic Analytics Cache"
safe_remove "$HOME/Library/Caches/com.apple.memoryanalyticsd" "Memory Analytics Cache"

# Siri and Assistant Caches
log_message "--- Cleaning Siri & Assistant Caches ---"
safe_remove "$HOME/Library/Caches/com.apple.siri" "Siri Cache"
safe_remove "$HOME/Library/Caches/com.apple.assistant" "Assistant Cache"
safe_remove "$HOME/Library/Caches/com.apple.siriactionsd" "Siri Actions Cache"
safe_remove "$HOME/Library/Caches/com.apple.siriknowledged" "Siri Knowledge Cache"
safe_remove "$HOME/Library/Caches/com.apple.assistantd" "Assistant Daemon Cache"

# Enhanced Spotlight Caches (Major in Tahoe)
log_message "--- Cleaning Enhanced Spotlight Caches ---"
safe_remove "$HOME/Library/Caches/com.apple.spotlight" "Spotlight Cache"
safe_remove "$HOME/Library/Caches/com.apple.corespotlightd" "Core Spotlight Cache"
safe_remove "$HOME/Library/Caches/com.apple.spotlightknowledged" "Spotlight Knowledge Cache"
safe_remove "$HOME/Library/Metadata/CoreSpotlight" "Core Spotlight Metadata"

# Cloud Services Caches
log_message "--- Cleaning Cloud Services Caches ---"
safe_remove "$HOME/Library/Caches/com.apple.cloudd" "iCloud Daemon Cache"
safe_remove "$HOME/Library/Caches/com.apple.cloudphotod" "iCloud Photos Cache"
safe_remove "$HOME/Library/Caches/com.apple.findmy" "Find My Cache"
safe_remove "$HOME/Library/Caches/com.apple.icloud" "iCloud Cache"

# Analytics and Telemetry Caches
log_message "--- Cleaning Analytics & Telemetry Caches ---"
safe_remove "$HOME/Library/Caches/com.apple.analyticsagent" "Analytics Agent Cache"
safe_remove "$HOME/Library/Caches/com.apple.feedbackd" "Feedback Daemon Cache"
safe_remove "$HOME/Library/Caches/com.apple.diagnostics" "Diagnostics Cache"

# Media Services Caches
log_message "--- Cleaning Media Services Caches ---"
safe_remove "$HOME/Library/Caches/com.apple.mediaremoteagent" "Media Remote Cache"
safe_remove "$HOME/Library/Caches/com.apple.mediaanalysisd" "Media Analysis Cache"
safe_remove "$HOME/Library/Caches/com.apple.amp.mediasharingd" "Media Sharing Cache"

# System-wide caches (requires sudo)
log_message "--- Cleaning System-wide Caches ---"
if [ "$EUID" -eq 0 ]; then
    safe_remove "/Library/Caches/com.apple.analyticsd" "System Analytics Cache"
    safe_remove "/Library/Caches/com.apple.wifianalyticsd" "WiFi Analytics Cache"
    safe_remove "/Library/Caches/com.apple.osanalytics" "OS Analytics Cache"
    safe_remove "/var/folders/*/C/com.apple.analyticsagent" "Analytics Agent System Cache"
else
    log_message "ℹ️  Skipping system-wide caches (run with sudo for full cleanup)"
fi

# Standard macOS caches
log_message "--- Cleaning Standard macOS Caches ---"
safe_remove "$HOME/Library/Caches/com.apple.Safari" "Safari Cache"
safe_remove "$HOME/Library/Caches/com.apple.WebKit.WebContent" "WebKit Cache"
safe_remove "$HOME/Library/Caches/com.apple.WebKit.Networking" "WebKit Networking Cache"
safe_remove "$HOME/Library/Caches/com.apple.appstore" "App Store Cache"
safe_remove "$HOME/Library/Caches/com.apple.weather" "Weather Cache"

# Clear temporary files
log_message "--- Cleaning Temporary Files ---"
safe_remove "/tmp" "Temporary Files"
safe_remove "$HOME/Library/Caches/TemporaryItems" "User Temporary Items"

# Clear logs (optional)
log_message "--- Cleaning Old Logs ---"
find "$HOME/Library/Logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true
find "/var/log" -name "*.log" -mtime +7 -delete 2>/dev/null || true

# Restart bloat services
log_message "🚀 Restarting bloat disabler services..."
sudo launchctl load /Library/LaunchDaemons/com.user.disablebloatservices.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.user.disablebloatservices.agent.plist 2>/dev/null || true

log_message "=== Cache Cleanup Complete ==="
log_message "System restart recommended for full effect"

# Show disk space recovered
df -h / | tail -1 | awk '{print "💾 Available disk space: " $4 " (" $5 " used)"}'
