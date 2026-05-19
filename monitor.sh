#!/bin/bash

# --- Config ---
RECIPIENT="joeyjake18@gmail.com"
SCRIPT_URL="https://raw.githubusercontent.com/joeii18/mac-startup-tools/main/startup_processes.sh"

# Load credentials from .env if present
if [[ -f "$(dirname "$0")/.env" ]]; then
  source "$(dirname "$0")/.env"
fi

# --- Validate credentials ---
if [[ -z "$MAILTRAP_API_TOKEN" || -z "$MAILTRAP_INBOX_ID" ]]; then
  echo "[-] Mailtrap credentials not set."
  echo "    Create a .env file next to this script with:"
  echo ""
  echo "    MAILTRAP_API_TOKEN=your-api-token"
  echo "    MAILTRAP_INBOX_ID=your-inbox-id"
  exit 1
fi

# --- OS Detection ---
OS="$(uname -s)"
echo "=== Monitor Script ==="
echo "[*] OS detected: $OS"

# --- Incognito Detection ---
check_incognito() {
  local found=0

  case "$OS" in
    Darwin)
      if ps aux | grep -i "[G]oogle Chrome" | grep -q "\-\-incognito"; then
        echo "[+] Chrome incognito detected"; found=1
      fi
      if ps aux | grep -i "[C]hromium" | grep -q "\-\-incognito"; then
        echo "[+] Chromium incognito detected"; found=1
      fi
      if ps aux | grep -i "[f]irefox" | grep -qE "\-private|\-private\-window"; then
        echo "[+] Firefox private window detected"; found=1
      fi
      if ps aux | grep -i "[B]rave Browser" | grep -q "\-\-incognito"; then
        echo "[+] Brave incognito detected"; found=1
      fi
      if pgrep -x "Safari" &>/dev/null; then
        echo "[~] Safari running (private mode undetectable)"
      fi
      ;;
    Linux)
      if ps aux | grep -i "[g]oogle-chrome" | grep -q "\-\-incognito"; then
        echo "[+] Chrome incognito detected"; found=1
      fi
      if ps aux | grep -i "[f]irefox" | grep -qE "\-private|\-private\-window"; then
        echo "[+] Firefox private window detected"; found=1
      fi
      ;;
    *)
      echo "[-] Unsupported OS: $OS"; exit 1 ;;
  esac

  echo "$found"
}

result=$(check_incognito)
found=$(echo "$result" | tail -1)
echo "$result" | sed '$d'

if [ "$found" -ne 1 ]; then
  echo "[-] No incognito/private tabs detected. Exiting."
  exit 0
fi

# --- Fetch & run startup script ---
echo ""
echo "[*] Fetching startup_processes.sh from GitHub..."
TMP_SCRIPT=$(mktemp /tmp/startup_XXXXXX.sh)

if command -v curl &>/dev/null; then
  curl -fsSL "$SCRIPT_URL" -o "$TMP_SCRIPT"
elif command -v wget &>/dev/null; then
  wget -q "$SCRIPT_URL" -O "$TMP_SCRIPT"
else
  echo "[-] curl/wget not found."; exit 1
fi

chmod +x "$TMP_SCRIPT"
echo "[*] Running startup process scan..."
REPORT=$(bash "$TMP_SCRIPT" 2>&1)
rm -f "$TMP_SCRIPT"

# --- Send email via Mailtrap API ---
echo ""
echo "[*] Sending report to $RECIPIENT via Mailtrap API..."

HOSTNAME="$(hostname)"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

python3 - <<EOF
import urllib.request
import urllib.error
import json

token     = """$MAILTRAP_API_TOKEN"""
inbox_id  = """$MAILTRAP_INBOX_ID"""
recipient = """$RECIPIENT"""
hostname  = """$HOSTNAME"""
timestamp = """$TIMESTAMP"""
report    = """$REPORT"""

payload = json.dumps({
    "from": {"email": "monitor@local", "name": "Monitor Script"},
    "to":   [{"email": recipient}],
    "subject": f"[Monitor] Incognito detected on {hostname} at {timestamp}",
    "text": f"""Incognito/private browser session detected on {hostname}.

Startup Process Report
======================
{report}

--
Sent by monitor.sh on {timestamp}
"""
}).encode()

req = urllib.request.Request(
    f"https://sandbox.api.mailtrap.io/api/send/{inbox_id}",
    data=payload,
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    method="POST"
)

try:
    with urllib.request.urlopen(req) as res:
        print("[+] Email sent — check your Mailtrap inbox")
except urllib.error.HTTPError as e:
    print(f"[-] Failed: {e.code} {e.read().decode()}")
    exit(1)
EOF
