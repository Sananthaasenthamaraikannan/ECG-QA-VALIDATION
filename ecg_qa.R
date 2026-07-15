# ecg_qa.R
# ECG Data Quality Review — clinical-trial-style QA in R
# Author: Sananthaa Senthamaraikannan
# Purpose: Demonstrate the data-integrity checks a cardiac data processor performs
#          before ECG interval data enters a trial database. NOT clinical diagnosis.

# ---- Packages ----
library(tidyverse)

# ---- Config ----
FS <- 360  # sampling frequency (Hz). Set to match your dataset's header.
LEADS <- c("MLII", "V5")

# ============================================================================
# DATA SOURCE
# ----------------------------------------------------------------------------
# Path A (real data, recommended for the CV story): MIT-BIH Arrhythmia DB.
#   In R:  install.packages("remotes"); remotes::install_github("...")  # (WFDB readers exist)
#   Simplest cross-language route: use PhysioNet's Python `wfdb` to export CSV once,
#   OR download a record's CSV via PhysioNet's LightWAVE "export" if you prefer no code.
#   MIT-BIH record 100 = 2 leads (MLII, V5), 360 Hz. A 10s slice is ~3600 samples/lead.
#
# Path B (this repo's reproducible fallback): data/ecg_data.csv, a small synthetic
#   multi-lead set with KNOWN, labelled defects so the QA logic is verifiable.
#   Columns: time_s, MLII, V5, record
# ============================================================================

ecg <- read_csv("data/ecg_data.csv", show_col_types = FALSE)

# ---- 1. Visualise one record with annotated PQRST ----
plot_record <- function(df, rec, lead = "MLII") {
  d <- df %>% filter(record == rec)
  ggplot(d, aes(time_s, .data[[lead]])) +
    geom_line(linewidth = 0.3) +
    labs(title = paste0("ECG — ", rec, " (lead ", lead, ")"),
         x = "Time (s)", y = "Amplitude (mV)") +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank())
}

# Example annotated plot on the clean record (first full beat).
annotated_beat <- function(df, rec = "rec_clean", lead = "MLII") {
  d <- df %>% filter(record == rec, time_s >= 0.35, time_s <= 0.95)
  ggplot(d, aes(time_s, .data[[lead]])) +
    geom_line(linewidth = 0.4) +
    annotate("text", x = 0.34, y = 0.15, label = "P",  fontface = "bold") +
    annotate("text", x = 0.50, y = 1.02, label = "QRS", fontface = "bold") +
    annotate("text", x = 0.72, y = 0.28, label = "T",  fontface = "bold") +
    labs(title = paste0("Annotated PQRST — ", rec),
         x = "Time (s)", y = "Amplitude (mV)") +
    theme_minimal(base_size = 11)
}

# ---- 2. R-peak detection (simple threshold + refractory period) ----
detect_r_peaks <- function(x, fs = FS) {
  thr <- 0.6 * max(x, na.rm = TRUE)
  idx <- which(x > thr)
  peaks <- integer(0); last <- -1e9
  refractory <- as.integer(0.2 * fs)   # 200 ms: no two beats closer than this
  for (i in idx) {
    if (i - last > refractory) { peaks <- c(peaks, i); last <- i }
  }
  peaks
}

# ---- 3. QA routine: returns one row per record ----
qa_record <- function(d, fs = FS, leads = LEADS) {
  flags <- character(0)

  for (ld in leads) {
    sig <- d[[ld]]
    # (a) Dropped/flat lead: near-zero variance across whole recording
    if (sd(sig, na.rm = TRUE) < 0.01) {
      flags <- c(flags, paste0(ld, ": lead dropout (flat/zero signal)"))
    } else {
      # (b) Local flatline: any ~1s window with near-zero variance
      w <- fs; flat <- FALSE
      starts <- seq(1, length(sig) - w, by = w %/% 2)
      for (s in starts) {
        if (sd(sig[s:(s + w)], na.rm = TRUE) < 0.005) { flat <- TRUE; break }
      }
      if (flat) flags <- c(flags, paste0(ld, ": flatline segment detected"))
    }
    # (c) Excessive noise: large sample-to-sample differences
    if (sd(diff(sig), na.rm = TRUE) > 0.15) {
      flags <- c(flags, paste0(ld, ": excessive noise/artefact"))
    }
  }

  # (d) Heart-rate plausibility from primary lead
  peaks <- detect_r_peaks(d[["MLII"]], fs)
  if (length(peaks) > 1) {
    rr_s <- diff(peaks) / fs
    hr <- 60 / mean(rr_s)
    if (hr < 40 || hr > 120) {
      flags <- c(flags, sprintf("HR ~%.0f bpm outside plausible resting range", hr))
    }
    # Illustrative QTc check would go here if QT were measured/available.
  } else {
    flags <- c(flags, "insufficient R-peaks detected (review recording)")
  }

  tibble(
    record  = unique(d$record),
    n_flags = length(flags),
    status  = if (length(flags) == 0) "PASS" else "REVIEW",
    flags   = if (length(flags) == 0) "PASS" else paste(flags, collapse = "; ")
  )
}

# ---- 4. Run QA across all records ----
qa_summary <- ecg %>%
  group_split(record) %>%
  map_dfr(qa_record)

print(qa_summary)

# ---- 5. Save outputs ----
if (!dir.exists("outputs")) dir.create("outputs")
write_csv(qa_summary, "outputs/qa_summary.csv")

ggsave("outputs/annotated_beat.png", annotated_beat(ecg), width = 6, height = 3.2, dpi = 150)
walk(unique(ecg$record), function(r) {
  ggsave(paste0("outputs/wave_", r, ".png"), plot_record(ecg, r),
         width = 7, height = 2.6, dpi = 150)
})

message("QA complete. See outputs/qa_summary.csv")
