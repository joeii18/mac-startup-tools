#!/bin/bash

SCRIPT_URL="https://raw.githubusercontent.com/joeii18/mac-startup-tools/main/startup_processes.sh"
DOWNLOAD_PATH="$HOME/Downloads/startup_processes.sh"

check_incognito_mac() {
  local found=0

  # Chrome: incognito processes have --incognito flag
  if pgrep -x "Google Chrome" &>/dev/null; then
    if ps aux | grep -i "[G]oogle Chrome" | grep -q "\-\-incognito"; then
      echo "[+] Chrome incognito tab detected"
      found=1
    fi
  fi

  # Chromium
  if pgrep -x "Chromium" &>/dev/null; then
    if ps aux | grep -i "[C]hromium" | grep -q "\-\-incognito"; then
      echo "[+] Chromium incognito tab detected"
      found=1
    fi
  fi

  # Firefox: private windows use -private or -private-window flag
  if pgrep -x "firefox" &>/dev/null; then
    if ps aux | grep -i "[f]irefox" | grep -qE "\-private|\-private\-window"; then
      echo "[+] Firefox private window detected"
      found=1
    fi
  fi

  # Brave: uses --incognito flag like Chrome
  if pgrep -xi "Brave Browser" &>/dev/null; then
    if ps aux | grep -i "[B]rave Browser" | grep -q "\-\-incognito"; then
      echo "[+] Brave incognito tab detected"
      found=1
    fi
  fi

  # Safari: private mode is not detectable via process flags (sandboxed)
  if pgrep -x "Safari" &>/dev/null; then
    echo "[~] Safari is running (private mode not detectable via process flags)"
  fi

  echo "$found"
}

check_incognito_linux() {
  local found=0

  if ps aux | grep -i "[g]oogle-chrome" | grep -q "\-\-incognito"; then
    echo "[+] Chrome incognito tab detected"
    found=1
  fi

  if ps aux | grep -i "[f]irefox" | grep -qE "\-private|\-private\-window"; then
    echo "[+] Firefox private window detected"
    found=1
  fi

  echo "$found"
}

download_script() {
  echo ""
  echo "[*] Downloading startup_processes.sh from GitHub..."
  if command -v curl &>/dev/null; then
    curl -fsSL "$SCRIPT_URL" -o "$DOWNLOAD_PATH"
  elif command -v wget &>/dev/null; then
    wget -q "$SCRIPT_URL" -O "$DOWNLOAD_PATH"
  else
    echo "[-] Neither curl nor wget found. Cannot download."
    exit 1
  fi
  chmod +x "$DOWNLOAD_PATH"
  echo "[+] Downloaded to: $DOWNLOAD_PATH"
}

echo "=== Incognito Tab Detector ==="
echo ""

OS="$(uname -s)"

case "$OS" in
  Darwin)
    result=$(check_incognito_mac)
    found=$(echo "$result" | tail -1)
    echo "$result" | head -n -1
    ;;
  Linux)
    result=$(check_incognito_linux)
    found=$(echo "$result" | tail -1)
    echo "$result" | head -n -1
    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

if [ "$found" -eq 1 ]; then
  echo ""
  echo "[!] Incognito/private session found."
  download_script
else
  echo "[-] No incognito or private tabs detected."
fi
