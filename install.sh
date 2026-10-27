#!/bin/bash

# macOS Tahoe 26/27 Bloat Service Disabler - Installation Script
# Version: 2.5
#
# This script installs the macOS Bloat Service Disabler system including:
# - Main bloat service disabler script
# - Cache cleanup utility (separate)
# - LaunchDaemon for system-wide operation
# - LaunchAgent for user-specific operation
#
# Maintainer: realnoedelo
# License: MIT
# Repository: https://github.com/realnoedelo/Lean_Mac.git

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The one-file curl install documented in the README places only this script
# in the current directory.  Missing companion files are bootstrapped from
# the same repository into a private temporary directory below.
SOURCE_DIR="$SCRIPT_DIR"
BOOTSTRAP_DIR=""
# This fork is the tested distribution. Set LEAN_MAC_RAW_BASE_URL when
# running the installer from another fork or after the change is merged.
RAW_BASE_URL="${LEAN_MAC_RAW_BASE_URL:-https://raw.githubusercontent.com/realnoedelo/Lean_Mac/main}"
INSTALL_DIR="/usr/local/bin"
DAEMON_PLIST_DIR="/Library/LaunchDaemons"
CONFIG_DIR="/usr/local/etc"
PROFILE_FILE="$CONFIG_DIR/lean_mac.conf"
PROFILE="safe"

cleanup_bootstrap() {
    if [ -n "$BOOTSTRAP_DIR" ] && [ -d "$BOOTSTRAP_DIR" ]; then
        rm -rf "$BOOTSTRAP_DIR"
    fi
}
trap cleanup_bootstrap EXIT

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_title() {
    echo -e "${BLUE}[TITLE]${NC} $1"
}

# Function to check if running as root for system operations
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script needs to be run with sudo for system-wide installation."
        print_status "Usage: sudo ./install.sh"
        exit 1
    fi
}

# Function to get the actual user (not root when using sudo)
get_actual_user() {
    if [ -n "${SUDO_USER:-}" ]; then
        echo "$SUDO_USER"
    else
        whoami
    fi
}

# Function to get actual user's home directory
get_user_home() {
    local actual_user
    actual_user=$(get_actual_user)
    eval echo "~$actual_user"
}

choose_profile() {
    echo
    print_title "Choosing service profile"
    echo "The following profiles control only optional groups. Live Text/OCR, JPEG text recognition, Quick Look and image indexing remain protected."
    echo
    echo "  1) Safe (recommended)"
    echo "     Disables analytics/telemetry only. Lowest risk; smallest resource savings."
    echo "  2) Balanced"
    echo "     Also disables Siri/Apple Intelligence suggestions and optional store/social services."
    echo "     Siri, suggestions, weather/store background updates and some sharing features may change."
    echo "  3) Custom"
    echo "     Choose each optional group below. OCR/Live Text is never offered for disabling."
    echo
    local choice
    read -r -p "Select profile [1-3, default 1]: " choice
    case "$choice" in
        2) PROFILE="balanced" ;;
        3)
            PROFILE="custom"
            mkdir -p "$CONFIG_DIR"
            : > "$PROFILE_FILE"
            printf 'PROFILE=custom\n' >> "$PROFILE_FILE"
            local group answer
            for group in telemetry intelligence cloud store social; do
                case "$group" in
                    telemetry) print_status "Telemetry: analytics, diagnostics and Wi-Fi usage data; no user-facing feature loss." ;;
                    intelligence) print_warning "Siri/Apple Intelligence: disables Siri actions, proactive suggestions and AI background tasks." ;;
                    cloud) print_warning "Cloud/Music/Find My helpers: may affect Music cloud refresh; Find My labels remain protected." ;;
                    store) print_warning "Store/media helpers: may delay Weather, App Store and media-remote updates." ;;
                    social) print_warning "Social/keychain sharing helpers: may affect some sharing integrations; Handoff remains protected." ;;
                esac
                read -r -p "Disable $group group? [y/N]: " answer
                if [[ "$answer" =~ ^[Yy]$ ]]; then
                    printf 'GROUP_%s=1\n' "$group" >> "$PROFILE_FILE"
                fi
            done
            ;;
        *) PROFILE="safe" ;;
    esac
    if [ "$PROFILE" != "custom" ]; then
        mkdir -p "$CONFIG_DIR"
        printf 'PROFILE=%s\n' "$PROFILE" > "$PROFILE_FILE"
    fi
    chmod 0644 "$PROFILE_FILE"
    print_status "Selected profile: $PROFILE"
}

remove_previous_installation() {
    local actual_user user_home user_uid old_restore
    actual_user=$(get_actual_user)
    user_home=$(get_user_home)
    user_uid=$(id -u "$actual_user" 2>/dev/null || true)
    old_restore="$INSTALL_DIR/restore_macos_services.sh"

    if [ ! -e "$DAEMON_PLIST_DIR/com.user.disablebloatservices.plist" ] \
        && [ ! -e "$user_home/Library/LaunchAgents/com.user.disablebloatservices.agent.plist" ] \
        && [ ! -e "$INSTALL_DIR/disable_bloat_services.sh" ]; then
        return 0
    fi

    print_title "Removing previous installation"
    if [ -x "$old_restore" ]; then
        print_status "Restoring services disabled by the previous release..."
        if grep -q 'ASSUME_YES' "$old_restore" 2>/dev/null; then
            "$old_restore" --yes >/dev/null 2>&1 || print_warning "Previous services could not all be restored; continuing cleanup"
        else
            printf 'RESTORE\n' | "$old_restore" >/dev/null 2>&1 || print_warning "Previous services could not all be restored; continuing cleanup"
        fi
    fi
    launchctl bootout system "$DAEMON_PLIST_DIR/com.user.disablebloatservices.plist" 2>/dev/null || true
    launchctl bootout system/com.user.disablebloatservices 2>/dev/null || true
    if [ -n "$user_uid" ] && [ "$actual_user" != root ]; then
        sudo -u "$actual_user" launchctl bootout "gui/$user_uid" "$user_home/Library/LaunchAgents/com.user.disablebloatservices.agent.plist" 2>/dev/null || true
        sudo -u "$actual_user" launchctl bootout "gui/$user_uid/com.user.disablebloatservices.agent" 2>/dev/null || true
    fi
    rm -f "$DAEMON_PLIST_DIR/com.user.disablebloatservices.plist"
    rm -f "$user_home/Library/LaunchAgents/com.user.disablebloatservices.agent.plist"
    rm -f "$INSTALL_DIR/disable_bloat_services.sh" "$INSTALL_DIR/cleanup_caches.sh"
    rm -f "$INSTALL_DIR/restore_macos_services.sh" "$INSTALL_DIR/uninstall_bloat_disabler.sh"
    print_status "✅ Previous installation removed"
}

# Download the companion scripts when install.sh was fetched on its own.
# This keeps both documented install forms working: a full git clone and the
# short curl command from the README.
prepare_source_files() {
    local required_file
    local required_files=(
        "disable_bloat_services.sh"
        "cleanup_caches.sh"
        "restore_macos_services.sh"
    )

    for required_file in "${required_files[@]}"; do
        if [ ! -f "$SOURCE_DIR/$required_file" ]; then
            if [ -z "$BOOTSTRAP_DIR" ]; then
                BOOTSTRAP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/lean-mac.XXXXXX")
                SOURCE_DIR="$BOOTSTRAP_DIR"
                print_status "Companion files are missing; downloading the release set..."
            fi
            if ! curl -fsSL "$RAW_BASE_URL/$required_file" -o "$SOURCE_DIR/$required_file"; then
                print_error "Unable to download $required_file from $RAW_BASE_URL"
                exit 1
            fi
            chmod +x "$SOURCE_DIR/$required_file"
        fi
    done
}

# Function to install script files
install_scripts() {
    print_title "Installing script files..."
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Install main bloat service disabler
    if [ -f "$SOURCE_DIR/disable_bloat_services.sh" ]; then
        cp "$SOURCE_DIR/disable_bloat_services.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/disable_bloat_services.sh"
        print_status "✅ Installed: disable_bloat_services.sh"
    else
        print_error "❌ disable_bloat_services.sh is unavailable"
        exit 1
    fi
    
    # Install cache cleanup utility
    if [ -f "$SOURCE_DIR/cleanup_caches.sh" ]; then
        cp "$SOURCE_DIR/cleanup_caches.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/cleanup_caches.sh"
        print_status "✅ Installed: cleanup_caches.sh"
    else
        print_error "❌ cleanup_caches.sh is unavailable"
        exit 1
    fi
    
    # Install restore script
    if [ -f "$SOURCE_DIR/restore_macos_services.sh" ]; then
        cp "$SOURCE_DIR/restore_macos_services.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/restore_macos_services.sh"
        print_status "✅ Installed: restore_macos_services.sh"
    else
        print_error "❌ restore_macos_services.sh is unavailable"
        exit 1
    fi
}

# Function to create updated plist files
create_plist_files() {
    print_title "Creating launch configuration files..."
    
    local actual_user user_home
    actual_user=$(get_actual_user)
    user_home=$(get_user_home)
    local user_agent_dir="$user_home/Library/LaunchAgents"
    
    # Create user LaunchAgent directory
    mkdir -p "$user_agent_dir"
    chown "$actual_user:staff" "$user_agent_dir"
    
    # Create user log directory
    mkdir -p "$user_home/Library/Logs"
    chown "$actual_user:staff" "$user_home/Library/Logs"
    
    # Create LaunchDaemon plist (system-wide, runs as root)
    cat > "$DAEMON_PLIST_DIR/com.user.disablebloatservices.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.disablebloatservices</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/disable_bloat_services.sh</string>
        <string>--system-only</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/var/log/disable_bloat_services.log</string>
    
    <key>StandardErrorPath</key>
    <string>/var/log/disable_bloat_services.error.log</string>
    
    <key>StartInterval</key>
    <integer>60</integer>
    
    <key>ProcessType</key>
    <string>Background</string>
    
    <key>LaunchOnlyOnce</key>
    <false/>
    
    <key>UserName</key>
    <string>root</string>
    
    <key>GroupName</key>
    <string>wheel</string>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF
    
    # Create LaunchAgent plist (user-specific)
    cat > "$user_agent_dir/com.user.disablebloatservices.agent.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.disablebloatservices.agent</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/disable_bloat_services.sh</string>
        <string>--user-only</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>$user_home/Library/Logs/disable_bloat_services.log</string>
    
    <key>StandardErrorPath</key>
    <string>$user_home/Library/Logs/disable_bloat_services.error.log</string>
    
    <key>StartInterval</key>
    <integer>300</integer>
    
    <key>ProcessType</key>
    <string>Background</string>
    
    <key>LaunchOnlyOnce</key>
    <false/>
</dict>
</plist>
EOF
    
    # Set proper ownership
    chown "$actual_user:staff" "$user_agent_dir/com.user.disablebloatservices.agent.plist"
    
    print_status "✅ Created: LaunchDaemon plist (system-wide, 60s interval)"
    print_status "✅ Created: LaunchAgent plist (user-specific, 300s interval)"
}

rotate_error_logs() {
    local actual_user
    local user_home
    local user_error_log

    actual_user=$(get_actual_user)
    user_home=$(get_user_home)
    user_error_log="$user_home/Library/Logs/disable_bloat_services.error.log"

    if [ -f /var/log/disable_bloat_services.error.log ]; then
        mv -f /var/log/disable_bloat_services.error.log \
            /var/log/disable_bloat_services.error.log.previous 2>/dev/null || true
    fi
    if [ -f "$user_error_log" ]; then
        mv -f "$user_error_log" "$user_error_log.previous" 2>/dev/null || true
    fi
    : > /var/log/disable_bloat_services.error.log
    : > "$user_error_log"
    chown root:wheel /var/log/disable_bloat_services.error.log
    chown "$actual_user:staff" "$user_error_log"
}

# Function to load services
load_services() {
    print_title "Loading services..."

    local actual_user user_home user_uid
    actual_user=$(get_actual_user)
    user_home=$(get_user_home)
    user_uid=$(id -u "$actual_user")

    local daemon_plist="$DAEMON_PLIST_DIR/com.user.disablebloatservices.plist"
    local daemon_label="com.user.disablebloatservices"

    # Bootstrap LaunchDaemon (system-wide)
    if launchctl bootstrap system "$daemon_plist" 2>/dev/null; then
        print_status "✅ Bootstrapped: System-wide LaunchDaemon"
    else
        print_warning "⚠️  LaunchDaemon may already be running; reloading it..."
        launchctl bootout system "$daemon_plist" 2>/dev/null || true
        launchctl bootout "system/$daemon_label" 2>/dev/null || true
        sleep 1
        if launchctl bootstrap system "$daemon_plist" 2>/dev/null || launchctl load -w "$daemon_plist" 2>/dev/null; then
            print_status "✅ Reloaded: System-wide LaunchDaemon"
        elif launchctl print "system/$daemon_label" >/dev/null 2>&1; then
            print_status "✅ Existing: System-wide LaunchDaemon"
        else
            print_error "❌ Failed to load system LaunchDaemon"
            return 1
        fi
    fi

    # Bootstrap LaunchAgent (user-specific)
    local agent_plist="$user_home/Library/LaunchAgents/com.user.disablebloatservices.agent.plist"
    local agent_label="com.user.disablebloatservices.agent"
    if sudo -u "$actual_user" launchctl bootstrap "gui/$user_uid" "$agent_plist" 2>/dev/null; then
        print_status "✅ Bootstrapped: User-specific LaunchAgent"
    else
        print_warning "⚠️  LaunchAgent may already be running; reloading it..."
        sudo -u "$actual_user" launchctl bootout "gui/$user_uid" "$agent_plist" 2>/dev/null || true
        sudo -u "$actual_user" launchctl bootout "gui/$user_uid/$agent_label" 2>/dev/null || true
        sleep 1
        if sudo -u "$actual_user" launchctl bootstrap "gui/$user_uid" "$agent_plist" 2>/dev/null || sudo -u "$actual_user" launchctl load -w "$agent_plist" 2>/dev/null; then
            print_status "✅ Reloaded: User-specific LaunchAgent"
        elif sudo -u "$actual_user" launchctl print "gui/$user_uid/$agent_label" >/dev/null 2>&1; then
            print_status "✅ Existing: User-specific LaunchAgent"
        elif sudo -u "$actual_user" launchctl kickstart -k "gui/$user_uid/$agent_label" 2>/dev/null; then
            print_status "✅ Kickstarted: User-specific LaunchAgent"
        else
            print_error "❌ Failed to load user LaunchAgent"
            return 1
        fi
    fi
}

# Function to create uninstall script
create_uninstall_script() {
    print_title "Creating uninstall script..."
    
    cat > "$INSTALL_DIR/uninstall_bloat_disabler.sh" << 'EOF'
#!/bin/bash

# macOS Bloat Service Disabler - Uninstall Script
# This script removes the bloat service disabler system

print_status() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

if [ "$EUID" -ne 0 ]; then
    print_error "This script needs to be run with sudo."
    echo "Usage: sudo uninstall_bloat_disabler.sh"
    exit 1
fi

# Get actual user
actual_user="${SUDO_USER:-$(whoami)}"
user_home=$(eval echo "~$actual_user")

echo "Uninstalling macOS Bloat Service Disabler..."

# Unload services
launchctl unload /Library/LaunchDaemons/com.user.disablebloatservices.plist 2>/dev/null || true
sudo -u "$actual_user" launchctl unload "$user_home/Library/LaunchAgents/com.user.disablebloatservices.agent.plist" 2>/dev/null || true

# Remove files
rm -f /Library/LaunchDaemons/com.user.disablebloatservices.plist
rm -f "$user_home/Library/LaunchAgents/com.user.disablebloatservices.agent.plist"
 rm -f /usr/local/bin/disable_bloat_services.sh
 rm -f /usr/local/bin/cleanup_caches.sh
 rm -f /usr/local/bin/restore_macos_services.sh
 rm -f /usr/local/bin/uninstall_bloat_disabler.sh

print_status "✅ Uninstalled macOS Bloat Service Disabler"
print_status "Log files remain in ~/Library/Logs/ and /var/log/"
EOF
    
    chmod +x "$INSTALL_DIR/uninstall_bloat_disabler.sh"
    print_status "✅ Created: uninstall_bloat_disabler.sh"
}

# Function to run initial execution
run_initial_execution() {
    print_title "Running initial bloat service disabling..."
    
    print_status "🚀 Executing bloat service disabler (this may take a moment)..."
    if "$INSTALL_DIR/disable_bloat_services.sh"; then
        print_status "✅ Initial execution completed successfully"
    else
        print_warning "⚠️  Initial execution completed with some warnings (check logs)"
    fi
}

# Function to display post-installation information
show_post_install_info() {
    local actual_user user_home
    actual_user=$(get_actual_user)
    user_home=$(get_user_home)
    
    print_title "Installation Complete!"
    echo
    echo "==========================================="
    echo "🎉 macOS Bloat Service Disabler v2.5 Installed"
    echo "==========================================="
    echo
    echo "📍 Installed Components:"
    echo "  • Main script: $INSTALL_DIR/disable_bloat_services.sh"
    echo "  • Cache cleaner: $INSTALL_DIR/cleanup_caches.sh"
    echo "  • Restore script: $INSTALL_DIR/restore_macos_services.sh"
    echo "  • System daemon: /Library/LaunchDaemons/com.user.disablebloatservices.plist"
    echo "  • User agent: $user_home/Library/LaunchAgents/com.user.disablebloatservices.agent.plist"
    echo "  • Uninstaller: $INSTALL_DIR/uninstall_bloat_disabler.sh"
    echo "  • Profile: $PROFILE ($PROFILE_FILE)"
    echo
    echo "🔄 Service Schedule:"
    echo "  • System-wide: Every 60 seconds"
    echo "  • User-specific: Every 300 seconds (5 minutes)"
    echo
    echo "📋 Manual Commands:"
    echo "  • Run bloat disabler: sudo disable_bloat_services.sh"
    echo "  • Clean caches: sudo cleanup_caches.sh"
    echo "  • Restore services: sudo restore_macos_services.sh"
    echo "  • Reconfigure profile: edit $PROFILE_FILE and reload the launch jobs"
    echo "  • Uninstall: sudo uninstall_bloat_disabler.sh"
    echo
    echo "📝 Log Files:"
    echo "  • System log: /var/log/disable_bloat_services.log"
    echo "  • System error log: /var/log/disable_bloat_services.error.log"
    echo "  • User log: $user_home/Library/Logs/disable_bloat_services.log"
    echo "  • User error log: $user_home/Library/Logs/disable_bloat_services.error.log"
    echo "  • Cache log: $user_home/Library/Logs/cache_cleanup.log"
    echo
    echo "⚠️  Important Notes:"
    echo "  • The system checks bloat services every 60 seconds"
    echo "  • Cache cleaner runs separately - use manually or schedule as needed"
    echo "  • System restart recommended for full effect"
    echo "  • Monitor logs for any issues"
    echo
    echo "🔧 For support, visit: https://github.com/realnoedelo/Lean_Mac"
    echo "==========================================="
}

# Main installation function
main() {
    echo "==========================================="
    echo "🚀 macOS Tahoe 26/27 Bloat Service Disabler"
    echo "    Installation Script v2.5"
    echo "==========================================="
    echo
    
    # Check system compatibility
    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "This script is designed for macOS only."
        exit 1
    fi
    
    # Check macOS version
    macos_version=$(sw_vers -productVersion)
    print_status "Detected macOS version: $macos_version"

    case "$macos_version" in
        26.*|27.*)
            print_status "✅ macOS $macos_version is supported by this build"
            ;;
        *)
            print_warning "⚠️  This build targets macOS 26.x and 27.x; continuing on $macos_version"
            ;;
    esac
    
    # Warn about potential risks
    echo
    print_warning "⚠️  IMPORTANT DISCLAIMER:"
    echo "This tool disables various macOS services that may affect system functionality."
    echo "While designed to be safe, use at your own risk."
    echo "Essential services like AirDrop, Mail, and Find My are preserved."
    echo
    
    # Ask for confirmation
    read -p "Do you want to proceed with the installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Installation cancelled by user."
        exit 0
    fi
    
    # Run installation steps
    prepare_source_files
    remove_previous_installation
    choose_profile
    install_scripts
    create_plist_files
    rotate_error_logs
    load_services
    create_uninstall_script
    run_initial_execution
    show_post_install_info
}

# Check if running as root
check_root

# Run main installation
main 
