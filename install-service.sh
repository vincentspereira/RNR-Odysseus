#!/bin/bash
# Install Odysseus as a systemd service so it starts on boot and restarts on crash.
#
#   sudo ./install-service.sh
#
# Auto-detects your username and the repo directory and substitutes them into
# odysseus-ui.service, so it works no matter where you cloned the repo or what
# you named the folder. Requires a working venv at <repo>/venv (run
# ./start-linux.sh once first, or create the venv manually).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/odysseus-ui.service"

if [ ! -f "$TEMPLATE" ]; then
    echo "Error: odysseus-ui.service template not found in $SCRIPT_DIR" >&2
    exit 1
fi

if [ ! -x "$SCRIPT_DIR/venv/bin/uvicorn" ]; then
    echo "Error: venv not found at $SCRIPT_DIR/venv." >&2
    echo "       Run ./start-linux.sh first (or: python3 -m venv venv && venv/bin/pip install -r requirements.txt)." >&2
    exit 1
fi

# Resolve the owning user: when invoked via sudo, $SUDO_USER is the real user;
# otherwise fall back to the current user. systemd runs the app as this user.
SERVICE_USER="${SUDO_USER:-$USER}"
if [ -z "$SERVICE_USER" ] || [ "$SERVICE_USER" = "root" ]; then
    SERVICE_USER="$(id -un)"
fi

echo "Installing Odysseus UI service..."
echo "  user : $SERVICE_USER"
echo "  repo : $SCRIPT_DIR"
echo

# Substitute the placeholders into a temporary copy, then install it.
TMP_UNIT="$(mktemp)"
trap 'rm -f "$TMP_UNIT"' EXIT
sed -e "s|__USER__|$SERVICE_USER|g" \
    -e "s|__REPO_DIR__|$SCRIPT_DIR|g" \
    "$TEMPLATE" > "$TMP_UNIT"

echo "Generated unit:"
echo "------------------------------------------------------------"
cat "$TMP_UNIT"
echo "------------------------------------------------------------"
echo

install -m 0644 "$TMP_UNIT" /etc/systemd/system/odysseus-ui.service
systemctl daemon-reload
systemctl enable odysseus-ui
systemctl restart odysseus-ui
echo
echo "[OK] odysseus-ui installed and started."
echo "     Status:   systemctl status odysseus-ui"
echo "     Logs:     journalctl -u odysseus-ui -f"
echo "     Stop:     sudo systemctl stop odysseus-ui"
echo "               sudo systemctl disable odysseus-ui   (to stop boot-start)"
