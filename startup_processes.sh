#!/bin/bash

OS="$(uname -s)"

case "$OS" in

  Darwin)
    echo "=== Startup Processes (macOS) ==="
    echo ""

    echo "--- Launch Daemons (System-wide, run as root) ---"
    echo "[/Library/LaunchDaemons]"
    ls /Library/LaunchDaemons/ 2>/dev/null
    echo ""
    echo "[/System/Library/LaunchDaemons]"
    ls /System/Library/LaunchDaemons/ 2>/dev/null
    echo ""

    echo "--- Launch Agents (Per-user) ---"
    echo "[~/Library/LaunchAgents]"
    ls ~/Library/LaunchAgents/ 2>/dev/null
    echo ""
    echo "[/Library/LaunchAgents]"
    ls /Library/LaunchAgents/ 2>/dev/null
    echo ""
    echo "[/System/Library/LaunchAgents]"
    ls /System/Library/LaunchAgents/ 2>/dev/null
    echo ""

    echo "--- Login Items (GUI apps that launch at login) ---"
    osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null
    echo ""

    echo "--- Currently Loaded Launch Services (launchctl) ---"
    launchctl list | grep -v "^-" | head -50
    echo ""

    echo "--- Startup Kernel Extensions ---"
    kextstat 2>/dev/null | grep -v "com.apple" | head -20
    ;;

  Linux)
    echo "=== Startup Processes (Linux) ==="
    echo ""

    echo "--- Systemd Enabled Services ---"
    if command -v systemctl &>/dev/null; then
      systemctl list-unit-files --type=service --state=enabled 2>/dev/null
    else
      echo "systemctl not found"
    fi
    echo ""

    echo "--- SysVinit / rc.d Scripts ---"
    ls /etc/init.d/ 2>/dev/null
    echo ""

    echo "--- Cron Jobs (current user) ---"
    crontab -l 2>/dev/null || echo "No crontab for current user"
    echo ""

    echo "--- Cron Jobs (system-wide) ---"
    ls /etc/cron* 2>/dev/null
    echo ""

    echo "--- Autostart Desktop Entries ---"
    ls ~/.config/autostart/ 2>/dev/null
    ls /etc/xdg/autostart/ 2>/dev/null
    echo ""

    echo "--- Running Services ---"
    if command -v systemctl &>/dev/null; then
      systemctl list-units --type=service --state=running 2>/dev/null | head -30
    elif command -v service &>/dev/null; then
      service --status-all 2>/dev/null | head -30
    fi
    ;;

  MINGW*|CYGWIN*|MSYS*)
    echo "=== Startup Processes (Windows/Git Bash) ==="
    echo ""

    echo "--- Registry Run Keys (requires reg.exe) ---"
    reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" 2>/dev/null
    reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" 2>/dev/null
    echo ""

    echo "--- Startup Folder ---"
    ls "$APPDATA/Microsoft/Windows/Start Menu/Programs/Startup" 2>/dev/null
    ls "C:/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup" 2>/dev/null
    echo ""

    echo "--- Scheduled Tasks ---"
    schtasks /query /fo LIST 2>/dev/null | head -50
    ;;

  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;

esac
