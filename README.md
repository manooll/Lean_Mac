# macOS Tahoe 26.0 Bloat Service Disabler

[![macOS](https://img.shields.io/badge/macOS-Tahoe%2026.0-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.3-orange)](https://github.com/manooll/Lean_Mac/releases)

Is your Mac slower than it should be, heating up, or losing battery life too fast? You might be running dozens of hidden background processes—like Apple Intelligence and Spotlight AI—that eat up your resources even if you never use them.

This tool automatically disables 29+ unnecessary user services and background processes in macOS Tahoe 26.0, freeing up your Mac to be faster, quieter, and more private—while keeping everything you actually use, like **AirDrop, Mail, Exchange sync, and device location**.

## 🚀 How does it help?

- **Saves battery and memory** - Stops resource-hungry processes you don't need
- **Makes your Mac faster** - Frees up CPU for everyday work and creative tasks
- **Protects your privacy** - Disables analytics and telemetry collection
- **Easy to install and undo** - Simple setup with full restoration option

## 🎯 What This Tool Targets

This tool specifically disables the biggest resource consumers on macOS Tahoe 26.0:

- **Apple Intelligence services** (new in Tahoe 26.0)
- **Enhanced Spotlight indexing** with aggressive AI features
- **Cloud sync services** that constantly run in background
- **Analytics and telemetry** collection services
- **Media analysis** and processing daemons
- **29+ user-level services** (system services require manual execution)

## 📦 Components

### 1. **Bloat Service Disabler** (`disable_bloat_services.sh`)
- Disables 29+ unnecessary user services and processes
- Runs continuously (60s system-wide, 5min user-specific)
- **CRITICAL FIX**: Preserves Apple Mail sync services
- **NEW**: System update protection - won't interfere with updates
- Targets highest CPU consumers first

### 2. **Cache Cleanup Utility** (`cleanup_caches.sh`)
- Separate utility for cleaning system caches
- Removes Apple Intelligence cache files
- Cleans Spotlight, analytics, and media caches
- Can be run manually or scheduled independently

### 3. **Installation System** (`install.sh`)
- Automated installation with proper permissions
- Creates LaunchDaemons and LaunchAgents
- Includes uninstaller for easy removal
- Comprehensive logging and error handling

## 🎯 Priority Targets

### High CPU/Memory Consumers
- `mds_stores` - Spotlight metadata (can use 60%+ CPU)
- `mobileassetd` - System update daemon
- `homeenergyd` - Energy monitoring (high CPU)
- `dasd` - AI prediction scheduler
- `mediaanalysisd` - Media analysis (heavy CPU/RAM)

### Apple Intelligence (New in Tahoe 26.0)
- `intelligenceplatformd` - AI platform daemon
- `TGOnDeviceInferenceProviderService` - On-device AI inference
- `knowledgeconstructiond` - Knowledge construction
- `privatecloudcomputed` - Private cloud compute

### Enhanced Spotlight Services
- `corespotlightd` - Core spotlight with AI
- `spotlightknowledged` - Knowledge-based search
- Multiple `mdworker` processes

## 🔧 Installation

### Quick Install (Recommended)
```bash
# Download and run installation script
curl -fsSL https://raw.githubusercontent.com/manooll/Lean_Mac/main/install.sh -o install.sh
sudo bash install.sh
```

### Manual Installation
1. Clone the repository:
```bash
git clone https://github.com/manooll/Lean_Mac.git
cd macos-bloat-disabler
```

2. Run the installer:
```bash
sudo ./install.sh
```

### What Gets Installed
- **Main script**: `/usr/local/bin/disable_bloat_services.sh`
- **Cache cleaner**: `/usr/local/bin/cleanup_caches.sh`
- **System daemon**: `/Library/LaunchDaemons/com.user.disablebloatservices.plist`
- **User agent**: `~/Library/LaunchAgents/com.user.disablebloatservices.agent.plist`
- **Uninstaller**: `/usr/local/bin/uninstall_bloat_disabler.sh`

## 📋 Usage

### Automated Operation
After installation, the system runs automatically:
- **System-wide**: Every 60 seconds (high-priority targets)
- **User-specific**: Every 300 seconds (5 minutes)

### Manual Commands
```bash
# Run bloat service disabler (includes system services when run manually)
sudo disable_bloat_services.sh

# Clean system caches
sudo cleanup_caches.sh

# Restore disabled services
sudo restore_macos_services.sh
```

### Service Management
```bash
# Check service status
sudo launchctl list | grep disablebloatservices
launchctl list | grep disablebloatservices

# Manually load/unload services
sudo launchctl load /Library/LaunchDaemons/com.user.disablebloatservices.plist
sudo launchctl unload /Library/LaunchDaemons/com.user.disablebloatservices.plist
```

## 📊 Performance Impact

### Expected Resource Savings
- **CPU Usage**: 20-40% reduction in background CPU usage
- **Memory Usage**: 500MB-1GB RAM freed up
- **Disk I/O**: Significantly reduced background disk activity
- **Battery Life**: Improved battery life on laptops

### Monitoring
Check logs to see what's being disabled:
```bash
# System log
tail -f /var/log/disable_bloat_services.log

# User log
tail -f ~/Library/Logs/disable_bloat_services.log

# Cache cleanup log
tail -f ~/Library/Logs/cache_cleanup.log
```

## 🛡️ Safety Features

### Preserved Essential Services
- **AirDrop/Sharing**: `com.apple.sharingd`
- **Mail Services**: `com.apple.cloudd`, `com.apple.icloudmailagent`, `com.apple.syncdefaultsd`
- **Mail Encryption**: `com.apple.protectedcloudstorage.protectedcloudkeysyncing`
- **Exchange Sync**: `com.apple.exchange.exchangesyncd`
- **System Updates**: Protected from interference during updates

### Safe Operation
- Non-destructive: Only disables services, doesn't delete files
- **System Update Safe**: Automatically detects and avoids running during updates
- **Process Protection**: 47+ critical system processes are protected from termination
- Reversible: Includes complete restoration script
- Logged: All actions are logged for review
- Tested: Extensively tested on macOS Tahoe 26.0

## 🔍 What Gets Disabled

### Apple Intelligence Services (Tahoe 26.0)
- `com.apple.intelligenceplatformd`
- `com.apple.intelligencetasksd`
- `com.apple.intelligencecontextd`
- `com.apple.knowledgeconstructiond`
- `com.apple.privatecloudcomputed`

### Enhanced Spotlight Services
- `com.apple.corespotlightservice`
- `com.apple.spotlightknowledged`
- Multiple spotlight worker processes

### Cloud & Sync Services (Partially Disabled)
- ✅ `com.apple.icloud.searchpartyuseragent` - Find My network
- ✅ `com.apple.icloud.findmydeviced.findmydevice-user-agent` - Find My device
- ✅ `com.apple.findmy.findmylocateagent` - Find My location
- ✅ `com.apple.itunescloudd` - iTunes/Music cloud sync
- ❌ **PRESERVED**: `com.apple.cloudd` - Required for iCloud Mail
- ❌ **PRESERVED**: `com.apple.icloudmailagent` - Required for iCloud Mail
- ❌ **PRESERVED**: `com.apple.syncdefaultsd` - Required for Mail sync

### Analytics & Telemetry
- `com.apple.analyticsagent`
- `com.apple.feedbackd`
- `com.apple.diagnostics_agent`
- `com.apple.wifianalyticsd`

### Media & AI Processing
- `com.apple.mediaanalysisd`
- `com.apple.proactiveeventtrackerd`
- `com.apple.geoanalyticsd`
- `com.apple.memoryanalyticsd`

### Siri & Assistant
- `com.apple.siriactionsd`
- `com.apple.siriknowledged`
- `com.apple.assistantd`
- `com.apple.siriinferenced`

*[View complete list in the script]*

## 🗂️ File Structure

```
macos-bloat-disabler/
├── README.md                          # This file
├── LICENSE                            # MIT License
├── install.sh                         # Installation script
├── disable_bloat_services.sh          # Main bloat disabler
├── cleanup_caches.sh                  # Cache cleanup utility
├── com.user.disablebloatservices.plist # System daemon config
└── com.user.disablebloatservices.agent.plist # User agent config
```

## ⚠️ Important Notes

### Before Installation
- **Create a backup** of your system or create a restore point
- **Review the script** to understand what services will be disabled
- **Test on a non-critical system** first if possible

### After Installation
- **Monitor system behavior** for any issues
- **Check logs regularly** for any errors
- **System restart recommended** for full effect
- **Some services may re-enable** after system updates

### Compatibility
- Designed specifically for **macOS Tahoe 26.0**
- May work on earlier versions but not guaranteed
- **Apple Silicon and Intel Macs** both supported

## 🔧 Troubleshooting

### Common Issues

#### Services Keep Re-enabling
```bash
# Check if system updates are re-enabling services
sudo launchctl list | grep -E "(intelligence|spotlight|cloud)"
```

#### High CPU Usage Persists
```bash
# Check what's still running
top -o cpu | head -20
```

#### Log File Issues
```bash
# Reset log permissions
sudo chown $(whoami):staff ~/Library/Logs/disable_bloat_services.log
```

### Getting Help
1. Check the [Issues](https://github.com/manooll/Lean_Mac/issues) page
2. Review log files for error messages
3. Join our [Discussions](https://github.com/manooll/Lean_Mac/discussions)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup
```bash
git clone https://github.com/manooll/Lean_Mac.git
cd macos-bloat-disabler
```

### Testing
```bash
# Test installation (use a VM or test machine)
sudo ./install.sh

# Check logs
tail -f ~/Library/Logs/disable_bloat_services.log
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- macOS optimization community
- Contributors who tested and provided feedback
- Apple for creating an OS that needs optimization 😉

## 📈 Version History

### v2.3 (Current) - CRITICAL FIX
- **CRITICAL FIX**: Preserve Apple Mail sync services (`cloudd`, `icloudmailagent`, `syncdefaultsd`)
- **System Update Protection**: Automatically detects and prevents interference with system updates
- **Enhanced Process Protection**: 47+ critical system processes protected from termination
- **Improved Mail Compatibility**: Exchange sync and iCloud Mail services preserved
- **Safer Service Management**: Gentler process termination (SIGTERM before SIGKILL)
- **Update Detection**: Monitors for active installations, downloads, and updates
- **Enhanced Logging**: Better error handling and detailed operation logging
- **Performance Tracking**: Real-time statistics showing services disabled and processes killed

### v2.1
- **Enhanced Performance**: Deduplication, wildcards, and comprehensive performance metrics
- **Shell Compatibility Fixes**: Replaced `readarray` with compatible `while` loop for system shell
- **Variable Scope Improvements**: Fixed `local` variable usage outside functions
- **Process Protection Logic**: Fixed Adobe process targeting (Adobe ACCFinderSync now properly eliminated)
- **Enhanced Process Targeting**: Added Figma agents and improved process identification
- **Success Rate Tracking**: Real-time statistics showing services disabled and processes killed
- **System Optimization**: CPU usage reduced, memory optimized, improved battery life
- **Automatic Restart Protection**: Prevents eliminated processes from restarting
- **Performance Reporting**: Shows before/after process counts and success rates

### v2.0
- Consolidated and optimized for GitHub publishing
- Added Apple Intelligence service support
- Improved installation system
- Better logging and error handling
- Separate cache cleanup utility

### v1.0
- Initial release for macOS Tahoe 26.0
- Basic service disabling functionality

## 🔗 Links

- [GitHub Repository](https://github.com/manooll/Lean_Mac)
- [Latest Release](https://github.com/manooll/Lean_Mac/releases/latest)
- [Report Issues](https://github.com/manooll/Lean_Mac/issues)
- [Discussions](https://github.com/manooll/Lean_Mac/discussions)

---

**⚠️ Disclaimer**: This tool modifies system services and may affect system functionality. Use at your own risk. Always backup your system before using. The authors are not responsible for any damage or data loss. 