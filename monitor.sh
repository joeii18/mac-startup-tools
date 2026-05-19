#!/bin/bash

# --- Config ---
RECIPIENT="joeyjake18@gmail.com"
SENDER="${GMAIL_USER}"          # export GMAIL_USER=you@gmail.com
APP_PASS="${GMAIL_APP_PASS}"    # export GMAIL_APP_PASS=xxxx-xxxx-xxxx-xxxx
SCRIPT_URL="https://raw.githubusercontent.com/joeii18/mac-startup-tools/main/startup_processes.sh"

# --- Validate credentials ---
if [[ -z "$SENDER" || -z "$APP_PASS" ]]; then
  echo "[-] Set GMAIL_USER and GMAIL_APP_PASS environment variables first."
  echo "    export GMAIL_USER=you@gmail.com"
  echo "    export GMAIL_APP_PASS=your-app-password"
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

# --- Send email via Gmail SMTP ---
echo ""
echo "[*] Sending report to $RECIPIENT..."

python3 - <<EOF
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import datetime

sender   = """$SENDER"""
password = """$APP_PASS"""
recipient = """$RECIPIENT"""
hostname  = "$(hostname)"
timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
report    = """$REPORT"""

msg = MIMEMultipart()
msg["From"]    = sender
msg["To"]      = recipient
msg["Subject"] = f"[Monitor] Incognito detected on {hostname} at {timestamp}"

body = f"""Incognito/private browser session was detected on {hostname}.

Startup Process Report
======================
{report}

--
Sent by monitor.sh on {timestamp}
"""
msg.attach(MIMEText(body, "plain"))

try:
    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
        server.login(sender, password)
        server.sendmail(sender, recipient, msg.as_string())
    print("[+] Email sent successfully to $RECIPIENT")
except Exception as e:
    print(f"[-] Failed to send email: {e}")
    exit(1)
EOF
