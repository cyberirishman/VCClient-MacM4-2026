# Real-Time Voice Clone (RVC) — Apple Silicon (M4)

Turn your live microphone into **someone else's voice in real time** on an Apple
Silicon Mac. You speak; your students hear the target voice, low-latency enough
that your lip movement still matches. Built for a cyber-security class demo on
voice deepfakes.

This repo is a thin, reproducible **installer + launcher** around the
Apple-Silicon RVC fork [`qingbo1011/RVC-WebUI-MacOS`](https://github.com/qingbo1011/RVC-WebUI-MacOS).
It pins Python to **3.10** and manages everything in an isolated **uv** venv so
installs don't fight each other.

> **Why RVC?** A *trained* RVC model gives the most convincing clone at the
> lowest real-time latency of the good open options — it's not diffusion-based,
> so per-chunk inference is fast. 2–3 minutes of clean target audio is ideal.

---

## Requirements

- Apple Silicon Mac (M1–M4/M5), macOS. Tested target: **Mac Mini M4, 64 GB**.
- [Homebrew](https://brew.sh) installed.
- ~5 GB free disk (models + venv).

## Quick start

```bash
git clone <your-repo-url> VCClient   # or just use this folder
cd VCClient
./setup.sh                            # one command: deps, venv, models (~15-20 min)
```

Then:

```bash
./run-webui.sh        # 1) TRAIN — opens http://127.0.0.1:7865  (Train tab)
./run-realtime.sh     # 2) GO LIVE — load your .pth + .index, speak
```

(`make setup` / `make webui` / `make realtime` do the same thing.)

## What `setup.sh` does

1. Verifies macOS + Apple Silicon.
2. `brew install ffmpeg aria2 portaudio`.
3. Installs `uv` if missing; installs **pinned CPython 3.10**.
4. Creates `.venv` (Python 3.10).
5. Clones the upstream RVC fork into `RVC-WebUI-MacOS/`.
6. Installs **PyTorch 2.2.2 + torchaudio 2.2.2** (Metal/MPS), then the upstream
   pinned deps (gradio 3.34.0, numpy 1.23.5, faiss-cpu 1.7.3, fairseq 0.12.2, …),
   with an automatic **fairseq build fallback**.
7. Verifies `torch.backends.mps.is_available()`.
8. Downloads RVC base models (hubert / rmvpe / pretrained).
9. Writes `locked-requirements.txt` (exact frozen versions) for reproducibility.

## Training the voice (once, ~15–30 min on M4)

1. Drop a **clean, dry, single-speaker** 2–3 min WAV in `training_audio/`.
   No music, no reverb, consistent mic. This matters more than any setting.
2. `./run-webui.sh` → **Train** tab.
   - Experiment name: e.g. `targetvoice`; sample rate `48k` (or `40k` if slow).
   - Point it at `training_audio/`; pitch method **rmvpe**.
   - Process data → Feature extraction → Train (≈150–300 epochs) → Train index.
3. Output: `assets/weights/targetvoice.pth` + an `.index` under `logs/targetvoice/`.

## Going real-time

`./run-realtime.sh`, then in the GUI:

- Load `targetvoice.pth` + its `.index`.
- Input = your mic. Output = room speakers (in-person) **or** BlackHole for
  Zoom/screen-share (`brew install blackhole-2ch`).
- **Latency knob:** start Block time ≈ 0.25 s, small crossfade (~0.05 s). Lower
  for less delay, raise if it stutters. Index rate ~0.5–0.75 for realism.
- Nudge pitch/transpose a few semitones if your natural pitch is far from target.

## Reproducibility

After a successful install, `locked-requirements.txt` captures exact versions.
Restore anytime: `uv pip install -r locked-requirements.txt`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `fairseq` won't build | setup.sh auto-retries with `pip<24.1` + `--no-build-isolation`. |
| `MPS available: False` | Wrong torch/x86 Python — `make clean` then `./setup.sh`. |
| Real-time stutters | Raise Block time (~0.35 s); close heavy apps. |
| Clone sounds mushy | Cleaner sample, more epochs, raise index rate. |
| Delay too long | Lower Block time/crossfade; use a `40k` model. |
| No sound in Zoom | Zoom mic = BlackHole 2ch; GUI output = BlackHole 2ch. |

## Responsible use

This is an educational tool for demonstrating **voice-deepfake risk** — that
"I heard their voice" is no longer proof of identity. Get consent for any voice
you clone, keep trained models private, and don't use them to deceive. See
`LICENSE` (MIT). You are responsible for how you use it.

## Credits

- Upstream: [`qingbo1011/RVC-WebUI-MacOS`](https://github.com/qingbo1011/RVC-WebUI-MacOS)
  (Apple-Silicon fork of the RVC-Project WebUI).
- Installer/automation + docs in this repo: built for a Mac Mini M4 class demo.
