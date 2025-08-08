# Lean_Mac Repository Overview

## General Structure
- **disable_bloat_services.sh** – core script that disables system/user services and kills selected processes. It protects critical processes (`SYSTEM_UPDATE_PROTECTED`) and performs gentle termination (SIGTERM then SIGKILL) via `kill_process`. Services are disabled in categories (cloud/sync, AI, telemetry, media, etc.) and running processes are terminated before a final summary is logged  
- **cleanup_caches.sh** – utility to reclaim disk space by iterating through major cache directories, temp files, and trash. It calculates freed space per path and totals the savings at the end  
- **install.sh** – installer that copies scripts into `/usr/local/bin`, generates LaunchDaemon and LaunchAgent plists, loads them, creates an uninstaller, and runs an initial pass. The daemon runs every 60 s and the agent every 300 s  
- **restore_macos_services.sh** – companion script to re-enable all services, restart Spotlight indexing, and restart key services. It first confirms user intent, stops any running “bloat disabler,” then re-enables services and logs success metrics and reminders about re-indexing and telemetry restoration

Additional files include the LaunchDaemon (`com.user.disablebloatservices.plist`) and LaunchAgent (`com.user.disablebloatservices.agent.plist`) templates that the installer customizes and deploys.

## Important Things to Know
- All scripts expect macOS and heavy use of `launchctl`; root privileges are required for system‑wide operations.
- Logs are written under `~/Library/Logs` and `/var/log` for tracing actions and troubleshooting.
- The service lists are explicit and conservative; only specified daemons/agents are affected, and Mail/iCloud essentials are preserved.
- The uninstall and restore scripts let users revert changes, but Spotlight re-indexing and re-enabled telemetry may temporarily raise CPU and network usage.

## Pointers for Further Learning
1. **launchd & launchctl basics** – Understand how LaunchDaemons and LaunchAgents schedule recurring jobs and how to manage them.
2. **macOS service discovery** – Investigate additional system processes or daemons you might want to disable/restore by querying `launchctl list` and `pgrep`.
3. **Scripting best practices** – Review shell scripting patterns (error handling, logging, permission checks) used in the installer and service scripts.
4. **macOS performance tuning** – Explore how Spotlight indexing, analytics, and cloud services impact CPU, memory, and disk, and how to monitor these effects in Activity Monitor or via CLI tools.
