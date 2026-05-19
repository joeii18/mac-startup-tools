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
      if pgrep -x "Google Chrome" &>/dev/null; then
        count=$(osascript << 'ASCRIPT'
tell application "Google Chrome"
    set incogCount to 0
    repeat with w in every window
        if mode of w is "incognito" then set incogCount to incogCount + 1
    end repeat
    return incogCount
end tell
ASCRIPT
)
        if [[ "$count" -gt 0 ]]; then
          echo "[+] Chrome: $count incognito window(s) detected"; found=1
        fi
      fi

      if pgrep -x "Brave Browser" &>/dev/null; then
        count=$(osascript << 'ASCRIPT'
tell application "Brave Browser"
    set incogCount to 0
    repeat with w in every window
        if mode of w is "incognito" then set incogCount to incogCount + 1
    end repeat
    return incogCount
end tell
ASCRIPT
)
        if [[ "$count" -gt 0 ]]; then
          echo "[+] Brave: $count incognito window(s) detected"; found=1
        fi
      fi

      if ps aux | grep -i "[f]irefox" | grep -qE "\-private|\-private\-window"; then
        echo "[+] Firefox private window detected"; found=1
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
    MINGW*|CYGWIN*|MSYS*)
      if command -v powershell &>/dev/null; then
        # Chrome/Brave: WMI sees --incognito in command line on Windows
        count=$(powershell -NoProfile -Command "
          \$procs = Get-WmiObject Win32_Process | Where-Object {
            \$_.Name -match 'chrome|brave' -and \$_.CommandLine -like '*--incognito*'
          }
          \$procs.Count
        " 2>/dev/null)
        if [[ "$count" -gt 0 ]]; then
          echo "[+] Chrome/Brave: $count incognito process(es) detected"; found=1
        fi

        # Firefox: check for -private flag
        ff=$(powershell -NoProfile -Command "
          \$procs = Get-WmiObject Win32_Process | Where-Object {
            \$_.Name -match 'firefox' -and \$_.CommandLine -match '-private'
          }
          \$procs.Count
        " 2>/dev/null)
        if [[ "$ff" -gt 0 ]]; then
          echo "[+] Firefox: private window detected"; found=1
        fi
      else
        echo "[-] PowerShell not found — cannot detect incognito on Windows"
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
TMP_SCRIPT=$(mktemp "${TMPDIR:-/tmp}/startup_XXXXXX.sh")

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

BODY="Incognito/private browser session detected on $HOSTNAME.\n\nStartup Process Report\n======================\n$REPORT\n\n--\nSent by monitor.sh on $TIMESTAMP"

PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
    'from': {'email': 'monitor@local', 'name': 'Monitor Script'},
    'to': [{'email': '$RECIPIENT'}],
    'subject': '[Monitor] Incognito detected on $HOSTNAME at $TIMESTAMP',
    'text': sys.stdin.read()
}))
" <<< "$BODY")

RESPONSE=$(curl -s -o /tmp/mailtrap_resp.txt -w "%{http_code}" \
  -X POST "https://sandbox.api.mailtrap.io/api/send/$MAILTRAP_INBOX_ID" \
  -H "Authorization: Bearer $MAILTRAP_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [[ "$RESPONSE" == "200" ]]; then
  echo "[+] Email sent — check your Mailtrap inbox"
else
  echo "[-] Failed (HTTP $RESPONSE): $(cat /tmp/mailtrap_resp.txt)"
  exit 1
fi
