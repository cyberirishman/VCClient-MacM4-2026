#!/usr/bin/env bash
# =============================================================================
# setup.sh  —  Real-time voice-clone (RVC) installer for Apple Silicon (M-series)
# One command to build a reproducible, pinned environment with uv + Python 3.10.
# Safe to re-run: it skips steps that are already done.
# =============================================================================
set -eo pipefail

PYTHON_VERSION="3.10"
TORCH_PIN="torch==2.2.2 torchaudio==2.2.2"
UPSTREAM="https://github.com/qingbo1011/RVC-WebUI-MacOS.git"
UPSTREAM_DIR="RVC-WebUI-MacOS"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
mkdir -p training_audio   # drop your target-voice clips here (WAV/MP3/FLAC)

say()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m[!] %s\033[0m\n" "$*"; }
die()  { printf "\n\033[1;31m[x] %s\033[0m\n" "$*" >&2; exit 1; }

# --- 0. Sanity: macOS + Apple Silicon ---------------------------------------
say "Checking platform"
[ "$(uname)" = "Darwin" ] || die "This installer is for macOS. Detected: $(uname)."
if [ "$(uname -m)" != "arm64" ]; then
  warn "Not detected as arm64 (Apple Silicon). Continuing, but MPS acceleration may be unavailable."
fi

# --- 1. Homebrew system deps -------------------------------------------------
say "Checking Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  die "Homebrew not found. Install it first:
  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"
Then re-run ./setup.sh"
fi
say "Installing system packages (ffmpeg, aria2, portaudio)"
brew install ffmpeg aria2 portaudio || warn "brew install reported an issue; if the tools already exist this is fine."

# --- 2. uv -------------------------------------------------------------------
say "Checking uv"
if ! command -v uv >/dev/null 2>&1; then
  say "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # shellcheck disable=SC1090
  [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
fi
command -v uv >/dev/null 2>&1 || die "uv still not on PATH. Open a new terminal and re-run."
uv --version

# --- 3. Pinned Python 3.10 + isolated venv ----------------------------------
say "Installing pinned CPython $PYTHON_VERSION via uv"
uv python install "$PYTHON_VERSION"
if [ ! -d ".venv" ]; then
  say "Creating .venv (Python $PYTHON_VERSION)"
  uv venv --python "$PYTHON_VERSION" .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python --version | grep -q " 3.10" || die "venv is not Python 3.10. Delete .venv and re-run."

# --- 3b. Build backends: setuptools provides pkg_resources (librosa needs it) ---
# uv venvs ship bare; without this, `import librosa` fails with:
#   ModuleNotFoundError: No module named 'pkg_resources'
# Pin <70 because newer setuptools is removing pkg_resources.
say "Installing build backends (setuptools<70, wheel)"
uv pip install "setuptools<70" wheel

# --- 4. Clone upstream RVC (Apple-Silicon fork) ------------------------------
say "Fetching upstream RVC ($UPSTREAM_DIR)"
if [ ! -d "$UPSTREAM_DIR/.git" ]; then
  git clone "$UPSTREAM" "$UPSTREAM_DIR"
else
  say "Upstream already present; pulling latest"
  git -C "$UPSTREAM_DIR" pull --ff-only || warn "Could not fast-forward upstream; leaving as-is."
fi

# --- 4b. Force English UI (the fork hardcodes zh_CN in i18n/i18n.py) ---
say "Setting RVC UI language to English"
python3 - "$UPSTREAM_DIR/i18n/i18n.py" <<'PYEOF'
import io,sys
p=sys.argv[1]; s=io.open(p,encoding="utf-8").read()
if 'language = "zh_CN"' in s:
    io.open(p,"w",encoding="utf-8").write(s.replace('language = "zh_CN"','language = "en_US"'))
    print("  UI language -> en_US")
else:
    print("  UI language already patched")
PYEOF

# --- 4c. Patch macOS SOLA bug in real-time GUI (torch.max needs dim=0) ---
say "Patching real-time GUI SOLA line for macOS"
python3 - "$UPSTREAM_DIR/gui_v1.py" <<'PYEOF'
import io,sys
p=sys.argv[1]; s=io.open(p,encoding="utf-8").read()
old="_, sola_offset = torch.max(cor_nom[0, 0] / cor_den[0, 0])"
new="_, sola_offset = torch.max(cor_nom[0, 0] / cor_den[0, 0], dim=0)"
if old in s:
    io.open(p,"w",encoding="utf-8").write(s.replace(old,new,1)); print("  SOLA line patched (dim=0)")
else:
    print("  SOLA line already patched or not found")
PYEOF

# --- 4d. Faiss threading fix in real-time module (cap ONLY faiss, keep torch fast) ---
say "Patching rvc_for_realtime.py to cap only faiss threads"
python3 - "$UPSTREAM_DIR/tools/rvc_for_realtime.py" <<'PYEOF'
import io,sys
p=sys.argv[1]; s=io.open(p,encoding="utf-8").read()
old="import faiss\nimport numpy as np"
new="import faiss\nfaiss.omp_set_num_threads(1)  # cap ONLY faiss threads (OpenMP-safe); torch keeps all cores\nimport numpy as np"
if "faiss.omp_set_num_threads(1)" in s:
    print("  already patched")
elif old in s:
    io.open(p,"w",encoding="utf-8").write(s.replace(old,new,1)); print("  faiss thread cap added")
else:
    print("  anchor not found - check manually")
PYEOF

# --- 4e. Fix malformed FileBrowse file_types in the real-time GUI ---
say "Patching gui_v1.py file-browse dialogs"
python3 - "$UPSTREAM_DIR/gui_v1.py" <<'PYEOF'
import io,sys
p=sys.argv[1]; s=io.open(p,encoding="utf-8").read()
s=s.replace('file_types=((". pth"),),','file_types=(("PTH files", "*.pth"),),')
s=s.replace('file_types=((". index"),),','file_types=(("Index files", "*.index"),),')
io.open(p,"w",encoding="utf-8").write(s)
print("  file-browse file_types fixed")
PYEOF

# --- 5. PyTorch (MPS) first, then app deps ----------------------------------
say "Installing PyTorch (Metal/MPS): $TORCH_PIN"
uv pip install $TORCH_PIN

say "Installing app requirements (pinned by upstream)"
if ! uv pip install -r "$UPSTREAM_DIR/requirements.txt"; then
  warn "Standard install failed (usually the fairseq build). Applying fallback."
  uv pip install "pip<24.1" setuptools wheel cython
  uv pip install --no-build-isolation fairseq==0.12.2
  uv pip install -r "$UPSTREAM_DIR/requirements.txt"
fi

say "Installing extra pins (sounddevice, torch guard)"
uv pip install -r requirements-extra.txt

# --- 6. MPS check ------------------------------------------------------------
say "Verifying Metal (MPS) is available"
python - <<'PY'
import torch
print("torch:", torch.__version__)
print("MPS available:", torch.backends.mps.is_available())
if not torch.backends.mps.is_available():
    print("[!] MPS not available — real-time will fall back to CPU (slower).")
PY

# --- 7. Base models ----------------------------------------------------------
say "Downloading RVC base models (hubert / rmvpe / pretrained)"
if [ -f "$UPSTREAM_DIR/tools/download_models.py" ]; then
  ( cd "$UPSTREAM_DIR" && python tools/download_models.py ) || warn "Model download script errored — see upstream README 'download models'."
else
  DL="$(ls "$UPSTREAM_DIR"/tools/ 2>/dev/null | grep -i download | head -1 || true)"
  if [ -n "$DL" ]; then
    ( cd "$UPSTREAM_DIR" && python "tools/$DL" ) || warn "Model download errored."
  else
    warn "No download script found. Grab base models per upstream README before training."
  fi
fi

# --- 8. Lock exact versions --------------------------------------------------
say "Freezing exact versions -> locked-requirements.txt"
uv pip freeze > locked-requirements.txt

say "DONE. Next steps:
  1) Put a clean 2-3 min WAV of the target voice in:  training_audio/
  2) Train:      ./run-webui.sh     (open http://127.0.0.1:7865  -> Train tab)
  3) Go live:    ./run-realtime.sh  (load your .pth + .index, tune Block time)

The run-*.sh scripts activate the Python venv automatically — you do NOT need to
activate it yourself. (Only run 'source .venv/bin/activate' to use raw python/uv.)

Restore this exact env anytime with:  uv pip install -r locked-requirements.txt"
