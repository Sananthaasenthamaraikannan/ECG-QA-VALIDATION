import wfdb
import pandas as pd
import os

# --- Save everything to a known folder on your Desktop ---
DATA_DIR = r"D:\ECG QA VALIDATION\DATA"
os.makedirs(DATA_DIR, exist_ok=True)

def export_signal(record_name, out_label, seconds=None):
    rec = wfdb.rdrecord(record_name, pn_dir="mitdb")
    fs = rec.fs
    df = pd.DataFrame(rec.p_signal, columns=rec.sig_name)
    df.insert(0, "time_s", df.index / fs)
    df["record"] = out_label
    if seconds is not None:
        df = df[df["time_s"] <= seconds]
    df = df.rename(columns={rec.sig_name[0]: "MLII", rec.sig_name[1]: "V5"})
    return df[["time_s", "MLII", "V5", "record"]]

# --- Signals for the QA pipeline (10s slices) ---
clean = export_signal("100", "mitbih_100_clean", seconds=10)
noisy = export_signal("108", "mitbih_108_noisy", seconds=10)
pd.concat([clean, noisy], ignore_index=True).to_csv(
    os.path.join(DATA_DIR, "ecg_data.csv"), index=False)
print("Saved ecg_data.csv")

# --- Annotations for validation (FULL record 100) ---
ann = wfdb.rdann("100", "atr", pn_dir="mitdb")
beat_symbols = set("NLRBAaJSVrFejnE/fQ")
beats = [(s, sym) for s, sym in zip(ann.sample, ann.symbol) if sym in beat_symbols]
ann_df = pd.DataFrame(beats, columns=["sample", "symbol"])
ann_df["time_s"] = ann_df["sample"] / 360
ann_df.to_csv(os.path.join(DATA_DIR, "annotations_100.csv"), index=False)
print(f"Saved annotations_100.csv — {len(ann_df)} real beats (from {len(ann.sample)} total markers)")

# --- Full clean signal (all 30 min) for validation ---
full_clean = export_signal("100", "mitbih_100_full", seconds=None)
full_clean.to_csv(os.path.join(DATA_DIR, "ecg_100_full.csv"), index=False)
print("Saved ecg_100_full.csv rows:", len(full_clean))

print("\nAll files saved to:", DATA_DIR)
