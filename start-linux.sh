#!/bin/bash
# Odysseus -- one-command quick start for Linux and WSL2.
#
#   ./start-linux.sh
#
# Sets up a local Python environment, installs dependencies, runs first-time
# setup, optionally starts a local ChromaDB, and launches the app -- so a
# generic Linux/WSL2 user can run Odysseus without knowing anything about
# venvs, pip, or uvicorn. Safe to re-run; it skips work that's already done.
#
# This is the Linux/WSL2 counterpart to start-macos.sh. It intentionally does
# NOT install system packages automatically (that needs root + the right
# distro's package manager); instead it prints the exact command to run when a
# required tool (python3, tmux) is missing, then exits so you stay in control.
#
# Overlays (all optional, via environment or .env):
#   ODYSSEUS_PORT / ODYSSEUS_HOST  -- host/port overrides (default 127.0.0.1:7000)
#   APP_PORT / APP_BIND            -- same, read from .env
#   ODYSSEUS_NO_OPEN=1             -- do not auto-open a browser (SSH / headless)
#   ODYSSEUS_NO_CHROMA=1           -- do not bootstrap a local ChromaDB
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Load .env so APP_PORT and APP_BIND are available without re-typing them on
# the command line every run -- consistent with how app.py reads them via
# python-dotenv. Variables already set in the shell take priority over .env.
if [ -f .env ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${key// }" ]] && continue
        value="${value%%#*}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        [ -n "$key" ] && [ -z "${!key+x}" ] && export "$key=$value"
    done < .env
fi

# Shell overrides take top priority, then .env values, then built-in defaults.
PORT="${ODYSSEUS_PORT:-${APP_PORT:-7000}}"
HOST="${ODYSSEUS_HOST:-${APP_BIND:-127.0.0.1}}"   # APP_BIND=0.0.0.0 for LAN/Tailscale.
PROBE_HOST="$HOST"
if [ "$PROBE_HOST" = "0.0.0.0" ] || [ "$PROBE_HOST" = "::" ]; then
    PROBE_HOST="127.0.0.1"
fi

# Friendly message on any failure -- re-running is safe (every step is idempotent).
trap 'echo; echo "[ERR] Setup failed above. It is safe to re-run ./start-linux.sh."; exit 1' ERR

echo ">> Odysseus quick start for Linux / WSL2"

# Fail fast if the port is already taken (e.g. a previous run still running).
if (exec 3<>"/dev/tcp/$PROBE_HOST/$PORT") 2>/dev/null; then
    echo "[ERR] Port $PORT is already in use on $PROBE_HOST. Stop what is using it, or pick another port:"
    echo "    ODYSSEUS_PORT=7001 ./start-linux.sh"
    exit 1
fi

# 1. Find a Python 3.11+ to build the environment with.
PY=""
for cand in python3 python3.13 python3.12 python3.11; do
    p="$(command -v "$cand" 2>/dev/null)" || continue
    if "$p" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3, 11) else 1)' 2>/dev/null; then
        PY="$p"; break
    fi
done
if [ -z "$PY" ] || [ ! -x "$PY" ]; then
    echo "[ERR] Python 3.11+ is required but was not found."
    echo "  Debian/Ubuntu:  sudo apt update && sudo apt install -y python3 python3-venv python3-pip"
    echo "  Fedora/RHEL:    sudo dnf install -y python3 python3-devel"
    echo "  Arch:           sudo pacman -S --noconfirm python"
    exit 1
fi
echo "  [OK] found $("$PY" --version 2>&1) at $PY"

# tmux is needed only by Cookbook (background model downloads/serves), not to
# boot the core app. Warn if it is missing but keep going.
if ! command -v tmux >/dev/null 2>&1; then
    echo "  [WARN] tmux is not installed -- Cookbook (local model serving) will be limited."
    echo "         Debian/Ubuntu: sudo apt install -y tmux"
    echo "         Fedora/RHEL:   sudo dnf install -y tmux"
    echo "         Arch:          sudo pacman -S --noconfirm tmux"
else
    echo "  [OK] tmux available (Cookbook ready)"
fi

# 2. Python environment + dependencies (kept inside the repo, in venv/).
#    Named `venv` to match the manual steps and the other launchers.
if [ ! -d venv ]; then
    echo ">> Creating Python environment..."
    "$PY" -m venv venv
fi
VENV_PY="./venv/bin/python3"
# Reinstall only when requirements.txt changed (fast no-op re-runs).
REQ_HASH="$(md5sum requirements.txt 2>/dev/null | cut -d' ' -f1)"
REQ_HASH_FILE="venv/.requirements_hash"
if [ ! -f "$REQ_HASH_FILE" ] || [ "$REQ_HASH" != "$(cat "$REQ_HASH_FILE" 2>/dev/null)" ]; then
    echo ">> Installing Python packages (first run downloads a few -- can take a few minutes)..."
    "$VENV_PY" -m pip install --quiet --upgrade pip
    # Not --quiet: this is the slow step, so show progress (and any real errors).
    "$VENV_PY" -m pip install -r requirements.txt
    echo "$REQ_HASH" > "$REQ_HASH_FILE"
else
    echo ">> Python packages up to date -- skipping install"
fi

# 3. First-run setup: creates data dirs and prints an initial admin password
#    the first time (idempotent -- does nothing if already set up). Suppress its
#    manual run hint -- we launch the server ourselves just below.
echo ">> Preparing Odysseus..."
ODYSSEUS_SKIP_RUN_HINT=1 ./venv/bin/python setup.py

# 4. ChromaDB backs the tool index and vector RAG. chromadb ships in the venv,
#    so start a local server before launching (unless one is already reachable,
#    CHROMADB_HOST points at a remote host, or the caller opted out).
CHROMA_PID=""
CHROMA_HOST="${CHROMADB_HOST:-localhost}"
CHROMA_PORT="${CHROMADB_PORT:-8100}"
# Pin bind + probe to IPv4 loopback: the app's "localhost" resolves to
# 127.0.0.1, but binding chroma to the literal "localhost" can land on IPv6 ::1,
# which the app cannot then reach.
CHROMA_BIN="$(dirname "$VENV_PY")/chroma"
case "$CHROMA_HOST" in
    localhost|127.0.0.1) CHROMA_BIND="127.0.0.1" ;;
    0.0.0.0)             CHROMA_BIND="0.0.0.0" ;;
    *)                   CHROMA_BIND="" ;;   # remote host - do not start locally
esac
if [ -n "$ODYSSEUS_NO_CHROMA" ]; then
    echo ">> Local ChromaDB bootstrap skipped (ODYSSEUS_NO_CHROMA set)"
elif (exec 3<>"/dev/tcp/127.0.0.1/$CHROMA_PORT") 2>/dev/null; then
    echo ">> ChromaDB already running on 127.0.0.1:$CHROMA_PORT -- using it."
elif [ -z "$CHROMA_BIND" ]; then
    echo ">> CHROMADB_HOST=$CHROMA_HOST is remote -- not starting a local ChromaDB."
elif [ -x "$CHROMA_BIN" ]; then
    CHROMA_LOG="${TMPDIR:-/tmp}/odysseus-chromadb.log"
    echo ">> Starting ChromaDB in the background on $CHROMA_BIND:$CHROMA_PORT..."
    echo "   logging to $CHROMA_LOG"
    nohup "$CHROMA_BIN" run --host "$CHROMA_BIND" --port "$CHROMA_PORT" --path "$PWD/data/chroma" >"$CHROMA_LOG" 2>&1 &
    CHROMA_PID=$!
else
    echo ">> ChromaDB CLI not found in venv; skipping (tool index will be degraded)."
fi

# 5. Launch. Bind to loopback by default; opt into LAN/Tailscale with
#    ODYSSEUS_HOST=0.0.0.0.
URL_HOST="$HOST"
if [ "$URL_HOST" = "0.0.0.0" ] || [ "$URL_HOST" = "::" ]; then
    URL_HOST="127.0.0.1"
fi
URL="http://$URL_HOST:$PORT"
TAILSCALE_URL=""
if [ "$HOST" = "0.0.0.0" ] && command -v tailscale >/dev/null 2>&1; then
    TS_IP="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
    if [ -n "$TS_IP" ]; then
        TAILSCALE_URL="http://$TS_IP:$PORT"
    fi
fi

# Open the browser automatically once the server is accepting connections, so
# the URL is not lost in the scrolling startup logs. Runs in the background and
# is cleaned up when the server stops. Skip with ODYSSEUS_NO_OPEN=1 (SSH/headless).
# In WSL2, prefer wslview (opens the URL in the Windows host browser); on native
# Linux fall back to xdg-open.
open_url() {
    if command -v wslview >/dev/null 2>&1; then
        wslview "$1" >/dev/null 2>&1 || true
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$1" >/dev/null 2>&1 || true
    fi
}
POLLER_PID=""
if [ -z "$ODYSSEUS_NO_OPEN" ]; then
    (
        for _ in $(seq 1 90); do
            if (exec 3<>"/dev/tcp/$PROBE_HOST/$PORT") 2>/dev/null; then
                printf '\n'
                printf '  +--------------------------------------------+\n'
                printf '  | [OK] Odysseus is ready -- opening browser   |\n'
                printf '  |     %-40s |\n' "$URL"
                printf '  |     (Press Ctrl+C in this window to stop)   |\n'
                printf '  +--------------------------------------------+\n\n'
                open_url "$URL"
                break
            fi
            sleep 1
        done
    ) &
    POLLER_PID=$!
fi

# Setup is done -- drop the setup-failure handler, and clean up the background
# opener and ChromaDB when the server exits or the user presses Ctrl+C.
trap - ERR
trap '[ -n "$POLLER_PID" ] && kill "$POLLER_PID" 2>/dev/null; [ -n "$CHROMA_PID" ] && kill "$CHROMA_PID" 2>/dev/null' EXIT INT TERM

echo
echo ">> Starting Odysseus -- it will open in your browser at $URL"
if [ -n "$TAILSCALE_URL" ]; then
    echo "   Tailscale/LAN URL: $TAILSCALE_URL"
fi
echo "   (this takes a few seconds; press Ctrl+C here to stop)"
echo
"$VENV_PY" -m uvicorn app:app --host "$HOST" --port "$PORT"
