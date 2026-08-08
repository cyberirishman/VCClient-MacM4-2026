#!/usr/bin/env bash
# Launch the RVC Web UI (training + file inference) at http://127.0.0.1:7865
set -eo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
[ -d .venv ] || { echo "No .venv — run ./setup.sh first."; exit 1; }
# shellcheck disable=SC1091
source .venv/bin/activate
cd RVC-WebUI-MacOS
# Entry point is the *.py file with 'web' in its name (e.g. infer-web.py).
ENTRY="$(ls *.py 2>/dev/null | grep -iE 'infer-web|^web|webui' | head -1)"
[ -n "$ENTRY" ] || ENTRY="infer-web.py"
echo "Launching Web UI: $ENTRY  ->  http://127.0.0.1:7865"
python "$ENTRY"
