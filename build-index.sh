#!/usr/bin/env bash
# Build the RVC feature .index WITHOUT the web UI (avoids the faiss/OpenMP
# segfault on Apple Silicon). Run this AFTER training, with nothing else running.
set -eo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$ROOT"
[ -d .venv ] || { echo "No .venv — run ./setup.sh first."; exit 1; }
# shellcheck disable=SC1091
source .venv/bin/activate
export OMP_NUM_THREADS=1
export KMP_DUPLICATE_LIB_OK=TRUE
EXP="${1:-elon_test}"
echo "Building faiss index for experiment: $EXP  (single-threaded, no web UI)"
python build_index.py "$EXP"
