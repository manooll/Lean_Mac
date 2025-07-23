#!/bin/bash

# macOS Tahoe 26.0 Bloat Service Disabler - Installation Script
# Version: 2.1
# 
# This script installs the macOS Bloat Service Disabler system including:
# - Main bloat service disabler script
# - Cache cleanup utility (separate)
# - LaunchDaemon for system-wide operation
# - LaunchAgent for user-specific operation
# 
# Author: Jay L. [Manull]
# License: MIT
# Repository: https://github.com/manooll/Lean_Mac.git

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
DAEMON_PLIST_DIR="/Library/LaunchDaemons"
AGENT_PLIST_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs"

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
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        echo "$(whoami)"
    fi
}

# Function to get actual user's home directory
get_user_home() {
    local actual_user=$(get_actual_user)
    eval echo "~$actual_user"
}

# Function to install script files
install_scripts() {
    print_title "Installing script files..."
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Install main bloat service disabler
    if [ -f "$SCRIPT_DIR/disable_bloat_services.sh" ]; then
        cp "$SCRIPT_DIR/disable_bloat_services.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/disable_bloat_services.sh"
        print_status "✅ Installed: disable_bloat_services.sh"
    else
        print_error "❌ disable_bloat_services.sh not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Install cache cleanup utility
    if [ -f "$SCRIPT_DIR/cleanup_caches.sh" ]; then
        cp "$SCRIPT_DIR/cleanup_caches.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/cleanup_caches.sh"
        print_status "✅ Installed: cleanup_caches.sh"
    else
        print_error "❌ cleanup_caches.sh not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Install restore script
    if [ -f "$SCRIPT_DIR/restore_macos_services.sh" ]; then
        cp "$SCRIPT_DIR/restore_macos_services.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/restore_macos_services.sh"
        print_status "✅ Installed: restore_macos_services.sh"
    else
        print_error "❌ restore_macos_services.sh not found in $SCRIPT_DIR"
        exit 1
    fi
}

# Function to create updated plist files
create_plist_files() {
    print_title "Creating launch configuration files..."
    
    local actual_user=$(get_actual_user)
    local user_home=$(get_user_home)
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
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/var/log/disable_bloat_services.log</string>
    
    <key>StandardErrorPath</key>
    <string>/var/log/disable_bloat_services.log</string>
    
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
    <true/>
    
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
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>$user_home/Library/Logs/disable_bloat_services.log</string>
    
    <key>StandardErrorPath</key>
    <string>$user_home/Library/Logs/disable_bloat_services.log</string>
    
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

# Function to load services
load_services() {
    print_title "Loading services..."
    
    local actual_user=$(get_actual_user)
    local user_home=$(get_user_home)
    
    # Load LaunchDaemon (system-wide)
    if launchctl load "$DAEMON_PLIST_DIR/com.user.disablebloatservices.plist" 2>/dev/null; then
        print_status "✅ Loaded: System-wide LaunchDaemon"
    else
        print_warning "⚠️  LaunchDaemon may already be loaded or failed to load"
    fi
    
    # Load LaunchAgent (user-specific) - run as actual user
    if sudo -u "$actual_user" launchctl load "$user_home/Library/LaunchAgents/com.user.disablebloatservices.agent.plist" 2>/dev/null; then
        print_status "✅ Loaded: User-specific LaunchAgent"
    else
        print_warning "⚠️  LaunchAgent may already be loaded or failed to load"
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
    local actual_user=$(get_actual_user)
    local user_home=$(get_user_home)
    
    print_title "Installation Complete!"
    echo
    echo "==========================================="
    echo "🎉 macOS Bloat Service Disabler v2.1 Installed"
    echo "==========================================="
    echo
    echo "📍 Installed Components:"
    echo "  • Main script: $INSTALL_DIR/disable_bloat_services.sh"
    echo "  • Cache cleaner: $INSTALL_DIR/cleanup_caches.sh"
    echo "  • Restore script: $INSTALL_DIR/restore_macos_services.sh"
    echo "  • System daemon: /Library/LaunchDaemons/com.user.disablebloatservices.plist"
    echo "  • User agent: $user_home/Library/LaunchAgents/com.user.disablebloatservices.agent.plist"
    echo "  • Uninstaller: $INSTALL_DIR/uninstall_bloat_disabler.sh"
    echo
    echo "🔄 Service Schedule:"
    echo "  • System-wide: Every 60 seconds"
    echo "  • User-specific: Every 300 seconds (5 minutes)"
    echo
    echo "📋 Manual Commands:"
    echo "  • Run bloat disabler: sudo disable_bloat_services.sh"
    echo "  • Clean caches: sudo cleanup_caches.sh"
    echo "  • Restore services: sudo restore_macos_services.sh"
    echo "  • Uninstall: sudo uninstall_bloat_disabler.sh"
    echo
    echo "📝 Log Files:"
    echo "  • System log: /var/log/disable_bloat_services.log"
    echo "  • User log: $user_home/Library/Logs/disable_bloat_services.log"
    echo "  • Cache log: $user_home/Library/Logs/cache_cleanup.log"
    echo
    echo "⚠️  Important Notes:"
    echo "  • The system will continuously disable bloat services"
    echo "  • Cache cleaner runs separately - use manually or schedule as needed"
    echo "  • System restart recommended for full effect"
    echo "  • Monitor logs for any issues"
    echo
    echo "🔧 For support, visit: https://github.com/manooll/Lean_Mac"
    echo "==========================================="
}

# Main installation function
main() {
    echo "==========================================="
    echo "🚀 macOS Tahoe 26.0 Bloat Service Disabler"
    echo "    Installation Script v2.1"
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
    install_scripts
    create_plist_files
    load_services
    create_uninstall_script
    run_initial_execution
    show_post_install_info
}

# Check if running as root
check_root

# Run main installation
main 