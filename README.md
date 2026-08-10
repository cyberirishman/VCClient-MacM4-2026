# VCClient-MacM4-2026 — Real-Time Voice Clone (RVC) for Apple Silicon

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
git clone https://github.com/CyberIrishman/VCClient-MacM4-2026.git
cd VCClient-MacM4-2026
./setup.sh
```

`./setup.sh` installs everything — dependencies, the Python 3.10 venv, and the
base models — in one pass (~15–20 minutes).

This voice changer needs two types of voice files     
The voice model file (.pth) and  and the index (.index file)    
You can find these on sites such as Github and go straight to Step 3, or train your own voice models  

**To train a voice** — launch the web UI - the training interface is launched in a browser:  

```bash
./run-webui.sh
```

Open the training web UI in a browser at <http://127.0.0.1:7865> (Train tab). Use it to train
your voice model (.pkt file **Stage 1** below), then build its index (.index file **Stage 2**). It takes
~60 seconds to start — open the URL in a browser yourself once it's up.

**Only after** you have a trained model   **and** its index (or downloaded them),   
go live with the integrated control panel :

```bash
./run-realtime.sh
```

Launches the real-time voice changer, where you load your `.pth` + `.index` and
speak. Running this before you have trained a model **won't work** — there's
nothing to load yet.

> **No need to activate the Python environment yourself** — `run-webui.sh`,
> `run-realtime.sh`, and `build-index.sh` each activate `.venv` automatically.
> (Only run `source .venv/bin/activate` if you want to use raw `python`/`uv`
> commands directly.)

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

## What a "model", `.pth`, and `.index` actually are

New to voice cloning? Here's how the pieces fit together, in plain terms.

**Training** is teaching the software what your target voice sounds like. You give
it a few minutes of that person speaking, and over many repetitions (called
*epochs*) it gradually learns the voice's unique characteristics — its tone,
timbre, and pitch patterns. Training is a one-time cost: once it finishes, you have
a reusable **model**.

**The model = the `.pth` file.** `.pth` is simply PyTorch's format for a saved
neural network, and this one file *is* the trained voice. Everything the software
learned gets packed into `assets/weights/voicefile.pth`. This is what you load to
convert speech: feed in your own voice, and the model reshapes it to sound like the
target. Copy this file to another machine and you have the voice there too — it's
the real deliverable.

**Feature extraction and the `.index` file** are a separate quality *refinement*
(and a file this GUI requires you to select — see below). Before training, the software chops your audio into tiny slices and
computes a numeric "fingerprint" for each one — that's *feature extraction*. The
**`.index`** is a fast, searchable library of all those fingerprints. During
conversion the model can consult it to find the closest real examples from your
training audio and lean toward them, which makes the output cling more tightly to
the target's actual sound.

A simple analogy: the **`.pth` is the artist** who paints in the target's style,
and the **`.index` is a reference photo album** the artist glances at to stay
accurate.

**The relationship that matters:** the `.pth` is **required** — it does the actual conversion. The `.index` only *refines* it. Conceptually the model can convert on its own — but in practice this real-time GUI won't start unless you also *select* an index file, so you always build one (Stage 2 below). On Apple Silicon you select it but keep **Index Rate at 0**: it stays loaded-but-inactive, the refinement is off (which avoids a deadlock), and the model alone is already a convincing clone.

## Where the models live — and using multiple voices

Everything a trained voice needs is stored **inside the upstream checkout**, keyed
by the **experiment name** you type on the Train tab:

- **Voice model:** `RVC-WebUI-MacOS/assets/weights/<name>.pth` — one `.pth` per voice.
- **Its index + training data:** `RVC-WebUI-MacOS/logs/<name>/` — holds the `.index`
  and the training checkpoints for that voice.

> **Full path on your Mac:** if you cloned into your home folder, these live under
> `/Users/YOUR_USERNAME/VCClient-MacM4-2026/` — e.g. the model is
> `/Users/YOUR_USERNAME/VCClient-MacM4-2026/RVC-WebUI-MacOS/assets/weights/<name>.pth`.

**Yes, you can train as many voices as you want** — just give each a different name,
and the name keeps them in separate files and folders so they never collide:

| Train with name | Model file | Index folder |
|---|---|---|
| `alice` | `assets/weights/alice.pth` | `logs/alice/…added_….index` |
| `bob`   | `assets/weights/bob.pth`   | `logs/bob/…added_….index`   |

To **switch voices at runtime**, just load the `.pth` (and its matching `.index`)
you want in the real-time GUI's **Load model** fields — no reinstall, no retraining.
Build each voice's index with `./build-index.sh <name>`.

> If you turned on "save small model at every checkpoint," you'll also see files like
> `<name>_e40_s1200.pth` in `assets/weights/` — those are snapshots of the **same**
> voice at different epochs, not separate voices. The plain `<name>.pth` is the final one.

## The workflow: three separate stages (once per voice)

Getting a working voice changer takes **three stages, done in order**. They are
genuinely different steps — keeping them straight avoids all the confusion:

| Stage | What it does | You run | Produces | Required? |
|---|---|---|---|---|
| **1. Train** | Learns your target voice (long, GPU-heavy) | `./run-webui.sh` | `voicefile.pth` — the model | **Yes** |
| **2. Build index** | Makes the index file the GUI needs to start | `./build-index.sh` | an `…added_….index` file | **Yes** |
| **3. Run live** | Converts your mic to the voice in real time | `./run-realtime.sh` | live converted audio | **Yes** |

**Is "build index" just part 2 of training? No.** Training (Stage 1) is what
creates the voice — the `.pth` model. Building the index (Stage 2) does **not**
train or improve the model; it's a separate lookup table. But you still **must**
build it, because the real-time GUI refuses to start unless an index file is
selected (it pops up *"please select an index file"*). The trick on Apple Silicon
is to select that index but keep **Index Rate at 0**: the file is loaded but never
actually searched — which satisfies the GUI while avoiding the deadlock that active
index retrieval causes (see the limitation note near the end).

## Stage 1 — Train the voice model → `voicefile.pth`

The long, one-time step that learns the voice. Do the sub-steps **in order**, and
**let each finish before starting the next** — they are separate operations.

**1. Add your audio.** Drop a **clean, dry, single-speaker** 2–5 min WAV into
`training_audio/`. No music, no reverb, consistent mic — this matters more than any
setting.

> **Several short clips work as well as one long file — no stitching needed.** RVC
> points at the *folder* and slices every file inside into short segments, pooling
> them into one set. Three ~1-minute WAVs behave like a single 3-minute file — just
> keep them the **same speaker**, similar mic/room, and each one clean.

**2. Launch the web UI, then open it in a browser.** Run `./run-webui.sh` and
**wait ~60 seconds** — the server takes about a minute to start. When the terminal
prints `Running on local URL: http://0.0.0.0:7865`, open a browser **yourself** to
<http://127.0.0.1:7865> (it does **not** open automatically). Click the **Train** tab.

**3. Fill in the settings** at the top of the Train tab:

- **Experiment name:** e.g. `voicefile`
- **Target sample rate:** `48k` (or `40k` if slow) — **Version:** `v2`
- **Dataset / training folder path:** the **full absolute path**, e.g.
  `/Users/YOUR_USERNAME/VCClient-MacM4-2026/training_audio`. A bare `training_audio/`
  or a `~/...` path will **not** resolve (the web UI runs from inside
  `RVC-WebUI-MacOS/` and does not expand `~`).
- **Pitch extraction algorithm:** `rmvpe`

**4. Click the buttons ONE AT A TIME — wait for each to finish before the next.**
The **Output information** box (right side of the Train tab) shows progress; wait
for the completion message before moving on:

1. Click <kbd>Process data</kbd>. Wait until Output information shows the success /
   `end preprocess` message.
2. Click <kbd>Feature extraction</kbd>. Wait until Output information shows
   **`all-feature-done`**.
3. Set **Save frequency = 25** and **Total training epochs = 200**, then click
   <kbd>Train model</kbd>. This is the long one — **hours** on an M4 (~100 s/epoch, so
   roughly 4–5.5 h for 200 epochs). **Two signs it finished (either confirms success):** the **Output information**
   box on the web page shows `训练结束, 您可查看控制台训练日志或实验文件夹下的train.log`
   — hardcoded Chinese for *"Training finished; check the console training log or
   the train.log in the experiment folder"* — **and** the terminal/console prints
   `saving final ckpt: Success`.

> ⚠️ **Do NOT click the UI's "Train feature index" button** — it segfaults on Apple
> Silicon. Building the index is **Stage 2**, done separately with `./build-index.sh`
> (seconds to minutes).

**5. Output:** `assets/weights/voicefile.pth` — your trained model. That single file
is the entire result of Stage 1.

**Timing & tips (measured on M4):** ~100 s/epoch for ~4 min of audio → 200 epochs
≈ 4–5.5 h; keep the Mac awake with `caffeinate -i` in a separate terminal. Voices
are usually recognizable by ~epoch 40–80. To audition partway and stop early, set
**"save small model at every checkpoint" = Yes** and use a smaller **Save frequency**
(e.g. 10) — each checkpoint then appears in `assets/weights/` and is loadable on the
Inference tab. Otherwise the final model is written only at the last epoch.

## Stage 2 — Build the feature index → `.index`  *(required — the GUI won't start without it)*

A separate, quick step that builds the lookup file from your training data. It is
**not** more training and does not touch the model — but you **must** build it,
because the real-time GUI won't start unless an index file is selected. (You keep
Index Rate at 0 in Stage 3, so the index is present but never actually searched —
that's what avoids the deadlock.)

Run it **after** Stage 1 finishes, with nothing else running:

```bash
./build-index.sh voicefile
```

Replace `voicefile` with your own experiment name if you trained under a
different one — it must match the name you used in Stage 1.

> **Why not the UI button?** The web UI's "Train feature index" button segfaults
> on Apple Silicon (faiss + OpenMP). `./build-index.sh` does the same job
> single-threaded and safely.

When it finishes it prints **both paths you need for Stage 3** — the model `.pth`
and the `.index` — ready to paste straight into the GUI's two fields.

## Stage 3 — Run it live (real-time voice change)

> ⚠️ **First-time only — grant your terminal microphone access, or you'll get
> total silence.** macOS blocks mic access per app. If your terminal (Terminal or
> iTerm2) isn't allowed, RVC receives **silence** and you'll hear nothing even
> though it looks like it's converting. Open **System Settings → Privacy & Security
> → Microphone**, enable your terminal app, then **fully quit it (Cmd+Q) and
> reopen** before running `./run-realtime.sh`. (The System Settings mic meter can
> move while your terminal still has no access — they're separate permissions.)

Now use your trained model. Run `./run-realtime.sh`, then in the GUI:

- **Load both** `voicefile.pth` **and** its `added_*.index` by **pasting each full
  path directly into its text field** — do **NOT** click the *Select the .pth file* /
  *Select the .index file* browse buttons. Both fields must be filled or the GUI
  won't start (it pops up *"please select an index file"*).
- **Index rate: leave at `0`** on Apple Silicon — this keeps the index loaded but
  inactive (active retrieval deadlocks real-time; see the limitation note). The
  model alone is already a convincing clone.
- **Input** = your mic. **Output** = room speakers (in person), or **BlackHole**
  for Zoom/screen-share (see *Audio routing* below).
- **Latency knob:** start Block time ≈ 0.25 s, small crossfade (~0.05 s); lower for
  less delay, raise if it stutters.
- Nudge **pitch/transpose** a few semitones if your natural pitch is far from the
  target's.

> **Where those two files are on disk** — the GUI's *Select the .pth file* and
> *Select the .index file* buttons open a file browser, so you need to know where
> to navigate. If you cloned into your home folder, they are:
>
> ```
> Model:  /Users/YOUR_USERNAME/VCClient-MacM4-2026/RVC-WebUI-MacOS/assets/weights/voicefile.pth
> Index:  /Users/YOUR_USERNAME/VCClient-MacM4-2026/RVC-WebUI-MacOS/logs/voicefile/added_IVF<N>_Flat_nprobe_1_voicefile_v2.index
> ```
>
> Swap `YOUR_USERNAME` for your Mac account name and `voicefile` for your
> experiment name. The `<N>` is a number `./build-index.sh` computes from your training data and prints when it
> finishes. (The GUI runs from inside `RVC-WebUI-MacOS/`, so typing the shorter
> relative paths `assets/weights/voicefile.pth` and
> `logs/voicefile/added_IVF<N>_Flat_nprobe_1_voicefile_v2.index` works too.)

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

## Cleanup / uninstall

Done experimenting? `cleanup.sh` reclaims the disk space (the base models + venv
are several GB) or removes the project entirely:

```bash
./cleanup.sh
./cleanup.sh --all
./cleanup.sh -h
```

`./cleanup.sh` **resets** — deletes `.venv` and `RVC-WebUI-MacOS/` (base models and
trained voices) but keeps the repo so you can re-run `./setup.sh`. `./cleanup.sh --all`
**fully removes** the whole project folder. `./cleanup.sh -h` shows help.

It lists what it will delete and asks you to type `yes` first (add `-y` to skip the
prompt). It does **not** touch Homebrew packages, `uv`, or the uv-managed Python
3.10 — those may be shared with other projects — but it prints the manual commands
to remove those too if you want a clean sweep.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `fairseq` won't build | setup.sh auto-retries with `pip<24.1` + `--no-build-isolation`. |
| `MPS available: False` | Wrong torch/x86 Python — `make clean` then `./setup.sh`. |
| Real-time stutters | Raise Block time (~0.35 s); close heavy apps. |
| Clone sounds mushy | Use a cleaner training sample and train more epochs. (Don't raise Index Rate on Apple Silicon — it deadlocks; keep it at 0.) |
| Delay too long | Lower Block time/crossfade; use a `40k` model. |
| No sound in Zoom | Zoom mic = BlackHole 2ch; GUI output = BlackHole 2ch. |
| Real-time runs but **no sound at all** (even Input-monitor mode) | Grant your terminal app mic access: System Settings → Privacy & Security → Microphone → enable Terminal/iTerm, then **Cmd+Q and reopen**. macOS feeds the process silence otherwise. |
| `No module named 'pkg_resources'` | `uv pip install "setuptools<70" wheel` (now baked into setup.sh). |
| `No module named 'FreeSimpleGUI'` | `uv pip install FreeSimpleGUI` (now in requirements-extra.txt). |
| GUI opens in Chinese | Fork hardcodes zh_CN; setup.sh now sets `i18n/i18n.py` to `en_US`. |
| `cannot import name 'media_data'` | `uv pip install "gradio==3.34.0" "gradio_client==0.2.7"` (pinned in requirements-extra.txt). |
| `Failed to load audio` on a non-audio file | Keep ONLY audio in `training_audio/`; RVC tries to decode every file. |
| Training dies at epoch 1: `no attribute 'tostring_rgb'` | `uv pip install "matplotlib==3.7.5"` (pinned in requirements-extra.txt). |
| `Segmentation fault: 11` on Train feature index | faiss/OpenMP crashes in the web UI on Apple Silicon. Use `./build-index.sh` instead — single-threaded, no web UI. |
| Real-time: `iteration over a 0-d tensor` (SOLA) | macOS bug in gui_v1.py — `torch.max(...)` needs `dim=0`. Fixed by setup.sh step 4c. |
| GUI file-browse button errors `too many values to unpack` | Malformed `file_types` in gui_v1.py; fixed by setup.sh step 4e. Workaround: paste the full path into the field instead of using the browse button. |
| `Index search FAILED or disabled` | **Expected** on Apple Silicon — you keep Index Rate at 0, so the index is loaded but not searched. Not an error. (Raising the rate to actually use it deadlocks real-time.) |

## Responsible use

This is an educational tool for demonstrating **voice-deepfake risk** — that
"I heard their voice" is no longer proof of identity. Get consent for any voice
you clone, keep trained models private, and don't use them to deceive. See
`LICENSE` (MIT). You are responsible for how you use it.

## Credits

- Upstream: [`qingbo1011/RVC-WebUI-MacOS`](https://github.com/qingbo1011/RVC-WebUI-MacOS)
  (Apple-Silicon fork of the RVC-Project WebUI).
- Installer/automation + docs in this repo: built for a Mac Mini M4 class demo.
