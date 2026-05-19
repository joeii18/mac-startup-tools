#!/bin/bash

echo "=== Mac Startup Processes ==="
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
