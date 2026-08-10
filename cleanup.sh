#!/usr/bin/env bash
# =============================================================================
# cleanup.sh — reclaim disk space, or fully remove this project.
#
#   ./cleanup.sh           RESET: delete the heavy generated stuff — the .venv,
#                          the cloned RVC-WebUI-MacOS/ (base models + your trained
#                          voices), and caches — but KEEP the repo source so you
#                          can re-run ./setup.sh later.
#   ./cleanup.sh --all     FULL: delete the ENTIRE project folder, source and all
#                          (including this script). Nothing of the project remains.
#   -y | --yes             Skip the confirmation prompt.
#   -h | --help            Show this help.
#
# It does NOT remove Homebrew packages, uv, or the uv-managed Python 3.10, because
# those may be shared with other projects. Commands to remove those by hand are
# printed at the end.
# =============================================================================
set -eo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="reset"; ASSUME_YES=0
for a in "$@"; do
  case "$a" in
    --all|--nuke) MODE="all" ;;
    -y|--yes)     ASSUME_YES=1 ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $a  (use -h for help)"; exit 1 ;;
  esac
done

say()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
size() { du -sh "$1" 2>/dev/null | cut -f1; }

# Generated / heavy items (all git-ignored) that RESET removes:
RESET_TARGETS=( ".venv" "RVC-WebUI-MacOS" "__pycache__" )

if [ "$MODE" = "all" ]; then
  say "FULL removal will delete the entire project folder:"
  echo "    $ROOT"
  warn "Everything goes: repo source, your trained voice model(s), the venv, this script."
else
  say "RESET will delete these generated items (repo source is kept):"
  for t in "${RESET_TARGETS[@]}"; do
    [ -e "$ROOT/$t" ] && printf "    %-20s %s\n" "$t" "$(size "$ROOT/$t")"
  done
  [ -d "$ROOT/training_audio" ] && printf "    %-20s %s\n" "training_audio/*" "$(size "$ROOT/training_audio")"
  warn "This removes your trained voice(s) and training clips. Rebuild later with ./setup.sh, then retrain."
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  printf "\nType 'yes' to proceed: "
  read -r ans
  [ "$ans" = "yes" ] || { echo "Aborted — nothing was deleted."; exit 0; }
fi

if [ "$MODE" = "all" ]; then
  say "Removing the whole project..."
  cd "$ROOT/.." || exit 1
  rm -rf "$ROOT"
  echo "Done. '$ROOT' has been removed."
else
  say "Removing generated files..."
  for t in "${RESET_TARGETS[@]}"; do
    if [ -e "$ROOT/$t" ]; then rm -rf "$ROOT/$t" && echo "    removed $t"; fi
  done
  if [ -d "$ROOT/training_audio" ]; then
    find "$ROOT/training_audio" -mindepth 1 -delete 2>/dev/null || true
    echo "    emptied training_audio/"
  fi
  say "Reset complete."
  echo "Re-run ./setup.sh to rebuild the environment and models, then retrain."
fi

cat <<'NOTE'

Not removed (may be shared with other projects) — delete by hand if you want them gone:
    brew uninstall ffmpeg aria2 portaudio      # audio dependencies
    brew uninstall blackhole-2ch               # only if you installed the virtual mic
    uv python uninstall 3.10                    # the uv-managed Python 3.10
    rm -rf ~/.local/bin/uv ~/.local/share/uv    # uv itself (only if nothing else uses it)
NOTE
