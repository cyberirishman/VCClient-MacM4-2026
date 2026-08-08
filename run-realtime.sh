#!/usr/bin/env bash
# Launch the real-time voice-conversion GUI (live mic -> cloned voice).
set -eo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
[ -d .venv ] || { echo "No .venv — run ./setup.sh first."; exit 1; }
# shellcheck disable=SC1091
source .venv/bin/activate
cd RVC-WebUI-MacOS
# Entry point is the *.py file with 'gui' in its name (e.g. gui_v1.py).
ENTRY="$(ls *.py 2>/dev/null | grep -iE 'gui' | head -1)"
[ -n "$ENTRY" ] || ENTRY="gui_v1.py"
echo "Launching real-time GUI: $ENTRY"
python "$ENTRY"
