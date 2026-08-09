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

   **You can use several short clips instead of one long file — no stitching
   needed.** RVC training points at the *folder*, and its preprocessing step
   scans every audio file inside, slices them all into short segments, and
   pools them into one training set. So three ~1-minute WAVs
   (`clip1.wav`, `clip2.wav`, `clip3.wav`) work exactly like a single 3-minute
   file. Just keep them the **same speaker** and, ideally, similar mic/room, and
   make sure each clip is individually clean (no music/reverb).
2. `./run-webui.sh` → **Train** tab.
   - Experiment name: e.g. `targetvoice`; sample rate `48k` (or `40k` if slow).
   - Point it at `training_audio/`; pitch method **rmvpe**.
   - Process data → Feature extraction → Train (≈150–300 epochs) → Train index.
3. Output: `assets/weights/targetvoice.pth` + an `.index` under `logs/targetvoice/`.

**Timing on M4 (measured): ~100 s/epoch** for ~4 min of audio. So 200 epochs ≈ 5.5 h
(train overnight), 100 epochs ≈ 2.8 h. To audition as it trains and stop early, set
**"save small model at every checkpoint" = Yes** and a small **Save frequency** (e.g. 10);
each checkpoint then appears in `assets/weights/` and is loadable on the Inference tab.
RVC voices are usually recognizable by ~epoch 40–80. Keep the Mac awake during long
runs with `caffeinate -i` in a separate terminal. The final small model is written to
`assets/weights/` only at the last epoch unless save-every-weights is on.

## Build the feature index

The web UI's "Train feature index" button often **segfaults on Apple Silicon**
(faiss + OpenMP). Use the bundled single-threaded builder instead — run it AFTER
training, with nothing else running:

```bash
./build-index.sh            # defaults to experiment name "elon_test"
./build-index.sh myexp      # or pass a different experiment name
```

It prints the path to the `added_*.index` file it creates under
`RVC-WebUI-MacOS/logs/<exp>/` — that's the one you load in the real-time GUI.

## Going real-time

`./run-realtime.sh`, then in the GUI:

- Load `targetvoice.pth` + its `.index`.
- Input = your mic. Output = room speakers (in-person) **or** BlackHole for
  Zoom/screen-share (`brew install blackhole-2ch`).
- **Latency knob:** start Block time ≈ 0.25 s, small crossfade (~0.05 s). Lower
  for less delay, raise if it stutters. Index rate ~0.5–0.75 for realism.
- Nudge pitch/transpose a few semitones if your natural pitch is far from target.

## Audio routing

RVC's real-time GUI is just a converter with two dropdowns — an **Input device**
and an **Output device**. It reads from the input (your mic), converts, and plays
the result to the output. **It does not create a virtual microphone by itself.**
Mental model:

```
mic  ->  [ RVC converts ]  ->  Output device
                               |-- real speakers   => humans in the room hear it
                               |-- BlackHole (virtual) => other apps see it as a mic
```

### Option A — In the room (simplest, no extra software)
Set **Input device** = your mic, **Output device** = your Mac/room speakers.
You talk, the room hears the cloned voice. Done. If the mic is near the speakers
you can get feedback — use a headset mic or add distance (the GUI also has a noise
threshold/gate to help).

### Option B — Over Zoom / Meet / Discord / OBS (needs a virtual mic)
You create the "new audio source" with a virtual audio driver. On macOS use
**BlackHole** (free):

```bash
brew install blackhole-2ch
```

After install, BlackHole appears as both an input and output device. Then:

1. In the RVC GUI, set **Output device = BlackHole 2ch**.
2. In Zoom/Meet/Discord/OBS, set the **microphone/input = BlackHole 2ch**.
   The app now "hears" the converted voice as if it were your mic.

**To also hear yourself** (otherwise output goes only to BlackHole, silent to you):
create a Multi-Output Device so the audio goes to BlackHole *and* your ears.

1. Open **Audio MIDI Setup** (in /Applications/Utilities).
2. Click **+** (bottom-left) -> **Create Multi-Output Device**.
3. Check both **BlackHole 2ch** and your **headphones/speakers**.
4. In the RVC GUI, set **Output device = that Multi-Output Device**.

Now the converted voice feeds the virtual mic (for the call) and your headphones
(for monitoring) at once.

> Tip: use headphones for monitoring so your mic doesn't pick up the output and
> create an echo/feedback loop.

## Real-time performance tuning

**Golden rule:** the terminal's `Infer time` must stay **below** your block time
(the "Sample length" slider) or audio stutters/drops.

- The **first block is always slow** (warm-up: model compile + MPS kernels). Let it
  run ~15 s and read the *steady-state* `Infer time`, not the first line.
- The index works in real time only with the OpenMP guards in `run-realtime.sh`
  (`OMP_NUM_THREADS=1`, `KMP_DUPLICATE_LIB_OK`). Running `gui_v1.py` outside the
  script (base python) will segfault when Index Rate > 0.
- If inference is too slow: raise **Sample length** to ~0.30 for headroom; switch
  pitch algorithm from **fcpe** to **rmvpe** (fcpe hits a slow CPU-fallback FFT on
  MPS — `aten::_fft_r2c`); or lower **Index Rate**.
> **Known limitation (Apple Silicon):** Index Rate > 0 can deadlock the audio thread
> in real time (processes one block, then hangs). If that happens, use **Index Rate 0** —
> the trained model alone is a convincing clone. This is the recommended demo setting.

- **Fallback:** at **Index Rate 0** (model only) it runs ~0.07 s/block — very smooth
  and still a convincing clone. Use this if the index makes real-time too heavy.
- The `KeyboardInterrupt` / `Process Harvest-N` tracebacks on Ctrl+C are the normal
  shutdown of the pitch-worker processes, not errors.

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
| `No module named 'pkg_resources'` | `uv pip install "setuptools<70" wheel` (now baked into setup.sh). |
| `No module named 'FreeSimpleGUI'` | `uv pip install FreeSimpleGUI` (now in requirements-extra.txt). |
| GUI opens in Chinese | Fork hardcodes zh_CN; setup.sh now sets `i18n/i18n.py` to `en_US`. |
| `cannot import name 'media_data'` | `uv pip install "gradio==3.34.0" "gradio_client==0.2.7"` (pinned in requirements-extra.txt). |
| `Failed to load audio` on a non-audio file | Keep ONLY audio in `training_audio/`; RVC tries to decode every file. |
| Training dies at epoch 1: `no attribute 'tostring_rgb'` | `uv pip install "matplotlib==3.7.5"` (pinned in requirements-extra.txt). |
| `Segmentation fault: 11` on Train feature index | faiss/OpenMP crashes in the web UI on Apple Silicon. Use `./build-index.sh` instead — single-threaded, no web UI. |
| Real-time: `iteration over a 0-d tensor` (SOLA) | macOS bug in gui_v1.py — `torch.max(...)` needs `dim=0`. Fixed by setup.sh step 4c. |
| `Index search FAILED or disabled` | Set **Index rate > 0** and load the **added_**`*.index` (not `trained_`). |

## Responsible use

This is an educational tool for demonstrating **voice-deepfake risk** — that
"I heard their voice" is no longer proof of identity. Get consent for any voice
you clone, keep trained models private, and don't use them to deceive. See
`LICENSE` (MIT). You are responsible for how you use it.

## Credits

- Upstream: [`qingbo1011/RVC-WebUI-MacOS`](https://github.com/qingbo1011/RVC-WebUI-MacOS)
  (Apple-Silicon fork of the RVC-Project WebUI).
- Installer/automation + docs in this repo: built for a Mac Mini M4 class demo.
