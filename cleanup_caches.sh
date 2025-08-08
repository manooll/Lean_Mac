#!/bin/bash

# macOS Cache Cleanup Script
# Cleans up heavy cache directories to free disk space
# Created: $(date)

LOG_FILE="$HOME/Library/Logs/cache_cleanup.log"
# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
TOTAL_FREED=0

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to get directory size in MB
get_dir_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sm "$dir" 2>/dev/null | awk '{print $1}' || echo "0"
    else
        echo "0"
    fi
}

# Function to clean cache directory
clean_cache() {
    local cache_dir="$1"
    local description="$2"
    local keep_recent="${3:-false}"
    
    if [ -d "$cache_dir" ]; then
        local size_before
        size_before=$(get_dir_size "$cache_dir")

        if [ "$keep_recent" = "true" ]; then
            # Keep files newer than 7 days
            find "${cache_dir:?}" -type f -mtime +7 -delete 2>/dev/null
        else

            # Remove all cache files safely
            rm -rf "${cache_dir:?}/"* 2>/dev/null
        fi

        local size_after
        size_after=$(get_dir_size "$cache_dir")
        local freed=$((size_before - size_after))
        TOTAL_FREED=$((TOTAL_FREED + freed))
        
        log_message "🧹 CLEANED: $description - ${freed}MB freed (was ${size_before}MB)"
    else
        log_message "ℹ️  NOT FOUND: $description"
    fi
}

log_message "=== Starting Cache Cleanup ==="

# Major cache directories
log_message "--- Cleaning Application Caches ---"
clean_cache "$HOME/Library/Caches/Arc" "Arc Browser Cache"
clean_cache "$HOME/Library/Caches/pip" "Python PIP Cache"
clean_cache "$HOME/Library/Caches/Homebrew" "Homebrew Cache"
clean_cache "$HOME/Library/Caches/SiriTTS" "Siri TTS Cache"
clean_cache "$HOME/Library/Caches/granola-updater" "Granola Updater Cache"
clean_cache "$HOME/Library/Caches/com.apple.python" "Apple Python Cache"
clean_cache "$HOME/Library/Caches/ms-playwright-go" "Playwright Cache"
clean_cache "$HOME/Library/Caches/node-gyp" "Node.js gyp Cache"
clean_cache "$HOME/Library/Caches/GeoServices" "GeoServices Cache"
clean_cache "$HOME/Library/Caches/com.apple.helpd" "Help Daemon Cache"

# System-related caches
log_message "--- Cleaning System Caches ---"
clean_cache "$HOME/Library/Caches/com.apple.nsurlsessiond" "URL Session Cache"
clean_cache "$HOME/Library/Caches/com.apple.Safari" "Safari Cache"
clean_cache "$HOME/Library/Caches/com.apple.WebKit.PluginProcess" "WebKit Plugin Cache"
clean_cache "$HOME/Library/Caches/com.apple.WebKit.WebContent" "WebKit Content Cache"
clean_cache "$HOME/Library/Caches/com.apple.WebKit.Networking" "WebKit Networking Cache"

# Developer caches
log_message "--- Cleaning Developer Caches ---"
clean_cache "$HOME/Library/Caches/com.apple.dt.Xcode" "Xcode Cache"
clean_cache "$HOME/Library/Developer/Xcode/DerivedData" "Xcode Derived Data"
clean_cache "$HOME/Library/Caches/com.docker.docker" "Docker Cache"
clean_cache "$HOME/.npm" "NPM Cache"
clean_cache "$HOME/.cargo/registry" "Rust Cargo Cache"
clean_cache "$HOME/.gradle/caches" "Gradle Cache"

# Temporary files
log_message "--- Cleaning Temporary Files ---"
clean_cache "/tmp" "System Temp Files" "true"
clean_cache "$HOME/Library/Logs" "Application Logs" "true"
clean_cache "$HOME/Library/Saved Application State" "App State Files"

# Trash
log_message "--- Emptying Trash ---"
if [ -d "$HOME/.Trash" ]; then
    trash_size=$(get_dir_size "$HOME/.Trash")
    find "$HOME/.Trash" -mindepth 1 -delete 2>/dev/null
    TOTAL_FREED=$((TOTAL_FREED + trash_size))
    log_message "🗑️  EMPTIED: Trash - ${trash_size}MB freed"
fi

# Download folder cleanup (files older than 30 days)
log_message "--- Cleaning Old Downloads ---"
if [ -d "$HOME/Downloads" ]; then
    downloads_before=$(get_dir_size "$HOME/Downloads")
    find "$HOME/Downloads" -type f -mtime +30 -delete 2>/dev/null
    downloads_after=$(get_dir_size "$HOME/Downloads")
    downloads_freed=$((downloads_before - downloads_after))
    TOTAL_FREED=$((TOTAL_FREED + downloads_freed))
    log_message "📥 CLEANED: Old Downloads - ${downloads_freed}MB freed"
fi

# System maintenance
log_message "--- Running System Maintenance ---"
if command -v brew >/dev/null 2>&1; then
    log_message "🍺 RUNNING: Homebrew cleanup"
    brew cleanup --prune=all >/dev/null 2>&1
    log_message "🍺 COMPLETED: Homebrew cleanup"
fi

# Docker cleanup if installed
if command -v docker >/dev/null 2>&1; then
    log_message "🐳 RUNNING: Docker cleanup"
    docker system prune -f >/dev/null 2>&1
    log_message "🐳 COMPLETED: Docker cleanup"
fi

log_message "=== Cache Cleanup Complete ==="
log_message "💾 TOTAL SPACE FREED: ${TOTAL_FREED}MB"
log_message "📊 RECOMMENDATION: Run this script monthly for optimal performance"

exit 0
