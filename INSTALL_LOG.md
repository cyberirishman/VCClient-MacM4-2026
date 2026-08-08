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
