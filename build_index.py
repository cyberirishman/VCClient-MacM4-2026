#!/usr/bin/env python3
"""Standalone faiss index builder for RVC (Apple Silicon safe).
Mirrors RVC's "Train feature index" but runs single-threaded to avoid the
faiss/OpenMP segfault seen inside the web UI on macOS arm64.
Usage: python build_index.py [experiment_name]   (default: voicefile)
"""
import os, sys, glob, traceback
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")
import numpy as np
import faiss


def main():
    exp = sys.argv[1] if len(sys.argv) > 1 else "voicefile"
    root = os.path.dirname(os.path.abspath(__file__))
    exp_dir = os.path.join(root, "RVC-WebUI-MacOS", "logs", exp)
    feat_dir = os.path.join(exp_dir, "3_feature768")
    dim = 768
    if not os.path.isdir(feat_dir):
        feat_dir = os.path.join(exp_dir, "3_feature256")
        dim = 256
    files = sorted(glob.glob(os.path.join(feat_dir, "*.npy")))
    if not files:
        print("ERROR: no feature .npy files found in", feat_dir)
        sys.exit(1)
    print(f"Loading {len(files)} feature files ({dim}-dim) from {feat_dir}")
    big = np.concatenate([np.load(f) for f in files], 0)
    order = np.arange(big.shape[0]); np.random.shuffle(order); big = big[order]
    print("Total feature vectors:", big.shape)

    faiss.omp_set_num_threads(1)
    n_ivf = max(1, min(int(16 * np.sqrt(big.shape[0])), big.shape[0] // 39))
    print("n_ivf =", n_ivf)
    index = faiss.index_factory(dim, f"IVF{n_ivf},Flat")
    ivf = faiss.extract_index_ivf(index); ivf.nprobe = 1
    print("Training index (single-threaded)...")
    index.train(big)
    trained = os.path.join(exp_dir, f"trained_IVF{n_ivf}_Flat_nprobe_1_{exp}_v2.index")
    faiss.write_index(index, trained)
    print("Adding vectors...")
    for i in range(0, big.shape[0], 8192):
        index.add(big[i:i + 8192])
    added = os.path.join(exp_dir, f"added_IVF{n_ivf}_Flat_nprobe_1_{exp}_v2.index")
    faiss.write_index(index, added)
    pth_path = os.path.join(root, "RVC-WebUI-MacOS", "assets", "weights", exp + ".pth")
    print("\n" + "=" * 72)
    print("DONE.  Use the following TWO paths in the real-time GUI.")
    print("Paste each directly into its text field - do NOT click the Select buttons.")
    print("=" * 72)
    print("\n  In the .pth field, paste this path:")
    print("    " + pth_path)
    if not os.path.exists(pth_path):
        print("    [!] .pth not found - check the model name / that training finished.")
    print("\n  In the .index field, paste this path:")
    print("    " + added)
    print("")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc(); sys.exit(1)
