# Install Log & Design Notes

Running record of the pertinent facts and decisions behind this repo, so the
GitHub version documents *why*, not just *how*. Append your real run output at
the bottom (Section 6) when you execute `./setup.sh` on the Mac.

## 1. Goal
Real-time voice conversion on a **Mac Mini M4 (64 GB)**: live mic in, a cloned
target voice out, low-latency, for a cyber-security class deepfake demo. The
user can supply **2–3 minutes** of clean target audio (ideal for RVC training).

## 2. Why RVC (trained) over the alternatives
- **RVC (chosen):** most convincing clone when *trained* on the target; not
  diffusion-based, so lowest real-time latency. 2–3 min audio is the sweet spot.
- **Seed-VC:** great zero-shot (1–30 s reference), but diffusion steps add
  latency; slightly less faithful than a trained RVC model.
- **VCClient / Beatrice:** easiest prebuilt app + very low latency, but arbitrary
  target cloning is weaker than a trained RVC model.
Decision: **RVC via the Apple-Silicon fork `qingbo1011/RVC-WebUI-MacOS`**, which
bundles both training and a real-time GUI.

## 3. Environment probe (bridge VM, 2026-08-08)
The Cowork device bridge exposes a **sandboxed Linux ARM VM**, NOT the macOS host,
and its network is allowlist-restricted:
```
uname -a : Linux ... aarch64 ... Ubuntu 22.04
network  : curl https://github.com -> HTTP 403 blocked-by-allowlist
present  : git, uv, ffmpeg, python3.10.12, curl
missing  : brew (expected on Linux), aria2
```
**Consequence:** the actual install cannot run through the bridge (wrong OS, no
Metal/MPS, no internet). It must run in a real macOS Terminal — hence this repo
is a self-contained installer the user runs with `./setup.sh`.

## 4. Pinned versions (the reproducibility contract)
- **Python: 3.10** (pinned via `uv`). Required — upstream's `fairseq==0.12.2`,
  `numba==0.56.4`, `numpy==1.23.5`, `gradio==3.34.0` do **not** build on 3.11+.
- **PyTorch: torch==2.2.2, torchaudio==2.2.2** (arm64 wheels w/ MPS).
- App deps come from upstream `requirements.txt` (gradio 3.34.0, numpy 1.23.5,
  faiss-cpu 1.7.3, librosa 0.9.1, pyworld 0.3.2, torchcrepe 0.0.20,
  fairseq 0.12.2, numba 0.56.4, llvmlite 0.39.0).
- `sounddevice==0.4.6` for live I/O.
- After first successful install, `locked-requirements.txt` freezes the exact set.

## 5. Known snag handled automatically
`fairseq==0.12.2` frequently fails to build on Apple Silicon. `setup.sh` catches
the failure and retries with `pip<24.1` + `--no-build-isolation`.

## 6. Real run output (fill in on the Mac)
Paste the tail of `./setup.sh`, the `MPS available:` line, training epoch count,
and the real-time Block time that felt best. This turns the repo into a tested,
reproducible record.

```
# (paste your ./setup.sh output here)
```

---

## 7. VERIFIED RUN — success (2026-08-08 02:59 UTC)
Host: Mac Mini M4 (64 GB), macOS, arm64.
`./setup.sh` completed cleanly:

```
==> Verifying Metal (MPS) is available
torch: 2.2.2
MPS available: True
All models downloaded.

==> Freezing exact versions -> locked-requirements.txt
==> DONE.
```

Result: Metal/MPS confirmed active (GPU acceleration available for real-time),
all RVC base models downloaded, exact versions frozen to `locked-requirements.txt`.
Environment reproducible via: `uv pip install -r locked-requirements.txt`.

Remaining: (1) train on a clean 2-3 min target WAV, (2) tune real-time Block time.

---

## 8. Fix — missing pkg_resources (2026-08-08 03:27 UTC)
First real-time launch failed: `ModuleNotFoundError: No module named 'pkg_resources'`
(raised inside `librosa 0.9.1`). Cause: uv venvs ship without setuptools, and the
setuptools install only lived in the fairseq *fallback* branch, which the clean
install never hit. Fix: `uv pip install "setuptools<70" wheel`. Now baked into
setup.sh (step 3b) and requirements-extra.txt so fresh installs won't hit it.

---

## 9. Fix — missing FreeSimpleGUI (2026-08-08 03:28 UTC)
Real-time launch failed: `ModuleNotFoundError: No module named 'FreeSimpleGUI'`
(`gui_v1.py` line 87). Upstream requirements.txt omits it. FreeSimpleGUI is the
open-source fork of PySimpleGUI (which moved to a paid license). Fix:
`uv pip install FreeSimpleGUI`. Added to requirements-extra.txt for fresh installs.
Watch for a follow-on `_tkinter` error if the uv Python lacks Tk.

---

## 10. Fix — GUI language (Chinese -> English) (2026-08-08 03:31 UTC)
The real-time GUI launched but in Simplified Chinese. Cause: the fork hardcodes
`language = "zh_CN"` in `i18n/i18n.py` (auto-detect commented out). A full
`i18n/locale/en_US.json` ships with the repo, so switching that one line to
`en_US` yields a fully English UI. Applied live, and added as setup.sh step 4b
so fresh installs come up in English.

---

## 11. Fix — gradio/gradio_client mismatch (2026-08-08 03:34 UTC)
Web UI (`infer-web.py`) failed: `ImportError: cannot import name 'media_data'
from 'gradio_client'`. Cause: upstream pins `gradio==3.34.0` but leaves
`gradio_client` unpinned, so the resolver installed a newer client that removed
`media_data`. Fix: pin `gradio_client==0.2.7` (matches gradio 3.34.0). Added to
requirements-extra.txt. Note: training log confirms `device: mps` (M4 GPU active).

---

## 12. Note — .gitkeep tripped preprocessing (2026-08-08 03:38 UTC)
Data preprocessing succeeded for all 4 target WAVs. The only error was on the
`training_audio/.gitkeep` placeholder: RVC's preprocessor runs ffmpeg on EVERY
file in the folder, so any non-audio file throws `Failed to load audio` (harmless
— that file is skipped). Removed the placeholder; `.gitignore` now ignores
`training_audio/` entirely and `setup.sh` recreates the empty folder on install.
Lesson: keep only audio files in `training_audio/`.

---

## 13. Fix — matplotlib tostring_rgb crash at epoch 1 (2026-08-08 03:48 UTC)
Training genuinely started (pretrained loaded, Epoch 1 ran, losses printed,
MPS + gloo backend working), then crashed at the epoch-1 TensorBoard summary:
`AttributeError: 'FigureCanvasAgg' object has no attribute 'tostring_rgb'`
in `infer/lib/train/utils.py` (plot_spectrogram_to_numpy). Cause: matplotlib
3.10 removed `tostring_rgb()`; upstream requirements didn't cap the version.
Fix: pin `matplotlib==3.7.5` (still provides tostring_rgb; compatible w/ numpy
1.23.5). Added to requirements-extra.txt. Data prep (109 slices, 76 features) was
unaffected and did not need redoing.

---

## 14. Training works — timing & overnight run (2026-08-08 04:08 UTC)
After the matplotlib fix, training runs cleanly on the M4 (MPS): Epoch 1 completed,
a fresh tfevents file grew to ~120 KB (vs the crashed run's frozen 88 B). Measured
speed: ~100 s/epoch for ~4 min of source audio. 200 epochs ≈ 5.5 h -> user chose to
train overnight. Notes for reproducibility:
- Default "save small model at every checkpoint" (if_save_every_weights18) = 否/No,
  so the small inference .pth lands in assets/weights/ only at the final epoch;
  G_/D_ training checkpoints save every save_every_epoch (25) to logs/<exp>/.
- To stop early with usable models, set that toggle = 是/Yes and a small save freq.
- Prevent system sleep during long training: `caffeinate -i` in a separate terminal.
- Build the .index via "Train feature index" (independent of epoch training).

---

## 15. Gotcha — segfault building index during training (2026-08-08 04:11 UTC)
Clicking "Train feature index" WHILE epoch training was running segfaulted the whole
web-UI process (`Segmentation fault: 11`, "leaked semaphore") and stopped training at
epoch 6. Cause: faiss (index build) and torch/MPS (training) initialize conflicting
OpenMP runtimes when run concurrently on macOS. Data intact (76 features); only ~6
epochs lost (no checkpoint yet). Fixes:
- ORDER OF OPERATIONS: build the feature index alone (before or after epoch training),
  never during.
- Hardened run-webui.sh / run-realtime.sh with `export KMP_DUPLICATE_LIB_OK=TRUE`.
Recovery: restart web UI -> Train feature index (verify .index) -> then Train model overnight.

---

## 16. Doc — Audio routing section added (2026-08-08 04:46 UTC)
Added an "Audio routing" section to README: clarifies RVC does NOT create a virtual
mic; Option A (in-room -> speakers) and Option B (virtual mic via `brew install
blackhole-2ch` -> set app mic to BlackHole, + Multi-Output Device for self-monitoring).

---

## 17. Fix — faiss index build segfaults in web UI (2026-08-08 13:41 UTC)
Training completed (200 epochs; assets/weights/voicefile.pth written). But the
web UI's "Train feature index" segfaults on Apple Silicon (`Segmentation fault:
11`) even with no training running — faiss's OpenMP conflicts with the process's
threading. KMP_DUPLICATE_LIB_OK alone did not prevent it. Solution: added a
standalone `build_index.py` + `build-index.sh` that build the faiss IVF index
single-threaded (OMP_NUM_THREADS=1, faiss.omp_set_num_threads(1)) outside the web
UI, mirroring RVC's index logic (768-dim v2 features -> added_*.index in
logs/<exp>/). Also added OMP_NUM_THREADS=1 to run-webui.sh as a fallback.

---

## 18. Index built + real-time ready (2026-08-09 17:11 UTC)
Feature index built via ./build-index.sh (single-threaded, no web UI): 9944
vectors, n_ivf=254 -> added_IVF254_Flat_nprobe_1_voicefile_v2.index (31.4 MB).
Both artifacts confirmed: assets/weights/voicefile.pth (57.5 MB) + the .index.
Added OMP_NUM_THREADS=1 to run-realtime.sh (faiss retrieval runs there too).
Ready for ./run-realtime.sh.

---

## 19. Fix — real-time SOLA crash + index-rate note (2026-08-09 17:20 UTC)
Real-time GUI ran (devices detected, model infer ~0.03s) but threw every audio
callback: `TypeError: iteration over a 0-d tensor` at gui_v1.py:977. Cause: the
fork's macOS branch does `_, sola_offset = torch.max(x)` with no dim -> torch.max
returns a 0-d scalar that can't unpack. Fix: `torch.max(x, dim=0)`. Patched live
and added to setup.sh (step 4c) for fresh installs. Also: "Index search FAILED or
disabled" was simply index_rate=0 (default); to use the index set Index rate > 0
and load the added_*.index (code rejects trained_*.index).

---

## 20. Real-time working end-to-end + tuning (2026-08-09 17:48 UTC)
Heard converted audio (once accidentally on base python -> crashed at Index Rate
0.5 due to missing OpenMP guards). In the venv via ./run-realtime.sh the index
runs in real time: "index = 0.024s", no segfault. The KeyboardInterrupt/Harvest
tracebacks are just Ctrl+C shutdown. Remaining tuning = speed: first block ~0.67s
is warm-up; steady-state Infer time must be < block time (Sample length). Levers:
raise Sample length to ~0.30; use rmvpe instead of fcpe (fcpe triggers CPU-fallback
aten::_fft_r2c on MPS); lower Index Rate; or Index Rate 0 (model-only, ~0.07s/block)
as a smooth fallback. Root cause of earlier crash: base python lacked the OMP guards
that run-realtime.sh sets.

---

## 21. Perf fix — isolate faiss threading (index without slowdown) (2026-08-09 18:07 UTC)
Index-on real-time was ~0.6s/block (too slow, stream stalled after 1 block) because
run-realtime.sh set a GLOBAL OMP_NUM_THREADS=1, throttling torch too. Fix (3 edits):
1) tools/rvc_for_realtime.py: added `faiss.omp_set_num_threads(1)` after `import faiss`
   (caps only faiss). 2) run-realtime.sh: removed global OMP_NUM_THREADS=1 (kept
   KMP_DUPLICATE_LIB_OK). 3) setup.sh step 4d re-applies the code patch on fresh clones.
Backup: tools/rvc_for_realtime.py.bak-omp. Revert = restore OMP_NUM_THREADS=1 + run index 0.

---

## 22. Conclusion — index deadlocks real-time; run at Index Rate 0 (2026-08-09 18:15 UTC)
The faiss thread-isolation fix did NOT resolve real-time with the index. Symptom:
with Index Rate > 0 it processes ONE (warm-up) block (~0.68s) then HANGS — the
faiss retrieval deadlocks against the sounddevice audio-callback thread on macOS
arm64 (index search itself is fast at 0.024s; not a speed issue). At Index Rate 0
there is no faiss call -> runs continuously ~0.07s/block, smooth, audible.
DECISION: run the classroom demo at Index Rate 0 (model-only). Quality is still a
convincing clone; the index is only a minor timbre refinement. Edits from step 21
are retained (harmless at index 0; faiss.omp_set_num_threads + no global OMP throttle
means index-0 runs with full torch threading). Real-time voice change: WORKING.
