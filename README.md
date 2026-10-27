# 🚀 macOS Tahoe 26/27 Bloat Service Disabler

[![macOS](https://img.shields.io/badge/macOS-Tahoe%2026%2F27-blue)](https://www.apple.com/macos/) [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) [![Version](https://img.shields.io/badge/Version-2.4-orange)](https://github.com/realnoedelo/Lean_Mac/releases)

> **Your Mac running hot? Battery draining fast? CPU spinning on "nothing"?**

macOS Tahoe 26.x and 27.x expose many background services through launchd. This tool inventories exact labels, disables the curated non-essential set, and reports what macOS SIP prevents from staying stopped.

This tool surgically disables the resource hogs while keeping everything you actually use: **AirDrop, Mail, Exchange sync, device location**. Your Mac, but faster, quieter, and more private.

**⚡ Install in seconds:**
```bash
curl -fsSL https://raw.githubusercontent.com/realnoedelo/Lean_Mac/main/install.sh -o install.sh && sudo bash install.sh
```

---

## ⚖️ Legal Disclaimer

**⚠️ Important:** This tool modifies macOS services and may affect system functionality. 

- **Not affiliated with Apple Inc.** Independent open-source utility, not authorized or endorsed by Apple
- **Use at your own risk** - Always backup your system before use
- **No warranty** - Authors not responsible for data loss, damage, or malfunction  
- **Educational/personal use only** - Check local laws for redistribution or commercial use
- **Apple trademarks** - All Apple product names used for identification only

---

## ✨ Why You'll Love It

- **⚡ Targets background services** that are safe to disable on the current OS
- **🔋 Reports target-process RSS and available-memory change** instead of promising a fixed gain
- **💾 Dramatically reduced disk I/O** (goodbye constant SSD writes)
- **🔒 Privacy restored** (analytics/telemetry disabled)
- **🛡️ Smart & safe** - Preserves essentials, breaks nothing
- **♻️ Fully reversible** - One command restores everything

---

## 🎯 The Resource Vampires We Kill

### Apple Intelligence (The New CPU Hogs)
```
intelligenceplatformd              # AI platform daemon  
TGOnDeviceInferenceProviderService # On-device AI inference
knowledgeconstructiond             # Knowledge construction
privatecloudcomputed               # Private cloud compute
intelligencetasksd                 # AI task scheduler
```

### Enhanced Spotlight (kept for image text search)
```
mds_stores                         # Image/document metadata index
corespotlightservice               # Core Spotlight index
spotlightknowledged                # Knowledge-based search
mdworker (multiple)                # Metadata workers
```

### Cloud and media background work
```
itunescloudd                      # iTunes/Music cloud sync
mediaanalysisd                    # Photo and video analysis
```

Mail, AirDrop, Exchange, Handoff, and Find My labels are inspected but
explicitly protected. They are never part of the automatic disable set.

### Analytics & Telemetry (The Spies)
```
analyticsagent                    # Usage analytics collection
feedbackd                         # Feedback harvesting
diagnostics_agent                 # Diagnostic data shipping
wifianalyticsd                    # WiFi usage tracking
```

### Optional media and telemetry processing
```
proactiveeventtrackerd           # Predictive behavior tracking
geoanalyticsd                    # Location analytics
memoryanalyticsd                 # Memory usage profiling
```

`mediaanalysisd`, Visual Intelligence, Core Spotlight and metadata workers are
kept enabled. macOS uses them for Live Text/OCR, Quick Look and searchable text
extraction from JPEG/PNG files.

---

## 📦 What You Get

### 1️⃣ **Bloat Service Disabler** (`disable_bloat_services.sh`)
- Kills optional background processes (targeting CPU hogs first)
- Runs automatically: once at login, then every 60s (system) / 5min (user)
- **Critical fix:** Mail sync and Live Text/OCR services preserved
- **Recovery:** re-enables protected labels left disabled by older releases
- **Smart:** Won't interfere with system updates

### 2️⃣ **Cache Cleanup Utility** (`cleanup_caches.sh`)  
- Purges Apple Intelligence caches and telemetry logs. Spotlight and media
  analysis data remain intact for Live Text/OCR and image search.
- Run manually or schedule independently

### 3️⃣ **Installation System** (`install.sh`)
- Sets up LaunchDaemons/Agents with proper permissions
- Includes clean uninstaller
- Comprehensive logging and error handling

---

## 🔧 Installation & Usage

**Files installed:**
```
/usr/local/bin/disable_bloat_services.sh       # Main bloat killer
/usr/local/bin/cleanup_caches.sh               # Cache cleaner  
/usr/local/bin/uninstall_bloat_disabler.sh     # Easy removal
/Library/LaunchDaemons/com.user.disablebloatservices.plist
~/Library/LaunchAgents/com.user.disablebloatservices.agent.plist
```

**Manual commands:**
```bash
sudo disable_bloat_services.sh    # Run full sweep (includes system services)
sudo disable_bloat_services.sh --profile safe       # Telemetry only
sudo disable_bloat_services.sh --interactive         # Ask with impact per label
sudo cleanup_caches.sh            # Purge system caches
sudo restore_macos_services.sh    # Restore everything
```

During installation the profile menu offers **Safe**, **Balanced** and
**Custom**. Safe disables telemetry/diagnostics only. Balanced also disables
optional Siri/Apple Intelligence and background helper groups. Custom asks for
each group and stores the choice in `/usr/local/etc/lean_mac.conf`. The
installer removes any previous Lean Mac jobs, restores their disabled labels
when possible, and then installs the selected profile.

**Service management:**
```bash
# Check status
sudo launchctl list | grep disablebloatservices

# Manual start/stop  
sudo launchctl load /Library/LaunchDaemons/com.user.disablebloatservices.plist
sudo launchctl unload /Library/LaunchDaemons/com.user.disablebloatservices.plist
```

---

## 🛡️ What Stays Protected

**Your essentials remain untouched:**
- **Mail Services:** `cloudd`, `icloudmailagent`, `syncdefaultsd`, `protectedcloudkeysyncing`
- **AirDrop/Sharing:** `sharingd`  
- **Find My:** `searchpartyuseragent`, `findmydeviced`, `findmylocateagent`, `findmymac`
- **Handoff/Continuity:** `rapportd`
- **Exchange Sync:** `exchangesyncd`
- **System Updates:** Protected from interference during updates
- **47+ critical system processes** safe from termination

---

## 📊 Performance Tracking

Each run writes measured values to the log; values depend on current workload:
```
Services disabled: <count>
Services already disabled: <count>
Services re-enabled: <count>
Processes killed: <count>
Processes respawned/SIP-protected: <count>
Available RAM before/after/change: <measured values>
Target-process RSS before/after/change: <measured values>
```

**Monitor the action:**
```bash
# Watch system-wide changes
tail -f /var/log/disable_bloat_services.log
tail -f /var/log/disable_bloat_services.error.log

# Monitor user-level changes  
tail -f ~/Library/Logs/disable_bloat_services.log
tail -f ~/Library/Logs/disable_bloat_services.error.log

# Cache cleanup activity
tail -f ~/Library/Logs/cache_cleanup.log
```

---

## 🧠 Smart Features

**System Update Protection**
- Auto-detects active installations/downloads
- Pauses bloat elimination during updates
- Resumes automatically when safe

**Gentle Process Management**  
- SIGTERM first, SIGKILL only if necessary
- 47+ critical processes protected from termination
- Process restart prevention

---

## ⚠️ Before You Install

- **Backup your system** (seriously, do this first)
- **Test on non-critical hardware** if possible
- **Read the code** - you're running this as root
- **macOS Tahoe 26.x and 27.x supported** (including 27.2)
- **SIP-protected Apple jobs may respawn**; the log reports them explicitly and does not count them as stopped
- **Restart recommended** after installation for full effect

### Service modes

The automatic mode checks exact launchd labels and records disabled, failed,
and missing services. For a read-only inventory of names discovered on the
current Mac:

```bash
sudo disable_bloat_services.sh --list
```

To review each candidate before changing it, use `sudo disable_bloat_services.sh
--interactive`. To validate the run without changing services or killing
processes, use `sudo disable_bloat_services.sh --dry-run`.

---

## 🛠️ Troubleshooting

**Services keep coming back?**
```bash
sudo launchctl list | grep -E "(intelligence|spotlight|cloud)"
```

SIP-protected Apple jobs may respawn. The log labels these as
`STILL RUNNING/RESPAWNED`; they are not reported as permanently stopped.

**Still high CPU usage?**
```bash
top -o cpu | head -20  # See what survived the purge
```

**Log permission issues?**
```bash
sudo chown $(whoami):staff ~/Library/Logs/disable_bloat_services.log
```

**Need help?**
1. Check [Issues](https://github.com/realnoedelo/Lean_Mac/issues) page
2. Review log files for error messages
3. Join [Discussions](https://github.com/realnoedelo/Lean_Mac/discussions)

---

## 📈 Version History

### v2.4 - SAFE PERIODIC RUNNER
- **Stopped the restart loop** by removing `KeepAlive=true` from the periodic LaunchDaemon
- **Recovered protected services** that older releases had accidentally disabled
- **Preserved Handoff/Continuity** (`rapportd`) alongside Mail, AirDrop, Exchange and Find My
- **Fixed root GUI verification** so `gui/0` is never queried and error logs stay clean
- **Expanded run accounting** with already-disabled, re-enabled and complete decision counts

### v2.3 - CRITICAL MAIL FIX 🚨
- **Fixed Mail services** (`cloudd`, `icloudmailagent`, `syncdefaultsd` now preserved)
- **System update protection** (won't break during macOS updates)
- **Enhanced process protection** (47+ critical processes safe)
- **Gentler termination** (SIGTERM → SIGKILL progression) 
- **Real-time performance stats** and success tracking

### v2.1 - Performance Beast
- **Shell compatibility fixes** (no more `readarray` issues)
- **Adobe process elimination** (goodbye ACCFinderSync)
- **Figma agent targeting** and improved process identification
- **Success rate tracking** with before/after metrics
- **Deduplication & wildcards** for better efficiency

### v2.0 - The GitHub Release
- **Apple Intelligence support** for Tahoe 26.x and 27.x
- **Consolidated installation** system
- **Separate cache cleanup** utility
- **Better logging** and error handling

---

## 🤝 Contributing

Found a new bloat service? Performance issue? We want to hear about it.

**Quick start:**
```bash
git clone https://github.com/realnoedelo/Lean_Mac.git
cd Lean_Mac
sudo ./install.sh  # Test on a VM first!
```

**Get involved:**
- [Report Issues](https://github.com/realnoedelo/Lean_Mac/issues)
- [Join Discussions](https://github.com/realnoedelo/Lean_Mac/discussions)
- Submit PRs with improvements

## 🧪 Testing

Run [`shellcheck`](https://www.shellcheck.net/) locally to catch shell script errors before
submitting changes:

```bash
./tests/shellcheck.sh
```

The script expects `shellcheck` to be installed (e.g. via `brew install shellcheck` on
macOS or `apt install shellcheck` on Debian/Ubuntu).

---

## 📄 License & Links

**MIT License** – [View Details](LICENSE)

- **[GitHub Repository](https://github.com/realnoedelo/Lean_Mac)**
- **[Latest Release](https://github.com/realnoedelo/Lean_Mac/releases/latest)**
- **[Report Issues](https://github.com/realnoedelo/Lean_Mac/issues)**

---

## 🙏 Acknowledgments

- macOS optimization community for testing and feedback
- Contributors who made this better
- Apple for creating an OS that keeps us busy 😉

---

**Final warning:** This modifies system services. Could break things. Use at your own risk. Back up first. Authors not responsible for your choices. But hey, it'll probably make your Mac way better. 🚀
