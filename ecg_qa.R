# ECG Data Exploration
# Author: Sananthaa Senthamaraikannan

library(tidyverse)
library(plotly)   

FS <- 360
LEADS <- c("MLII", "V5")
BASE <- "D:/ECG QA VALIDATION"

# DATA SOURCE — MIT-BIH Arrhythmia Database (PhysioNet), pulled via wfdb.
#   ecg_data.csv = 10s slices of record 100 (clean) + 108 (noisy).
#   Columns: time_s, MLII, V5, record

ecg <- read_csv(file.path(BASE, "DATA", "ecg_data.csv"), show_col_types = FALSE)

# Records present (so the annotated-beat default isn't hard-coded to old names)
CLEAN_REC <- ecg %>% distinct(record) %>% slice(1) %>% pull(record)

# Interactive full-record trace
plot_record <- function(df, rec, lead = "MLII") {
  d <- df %>% filter(record == rec)
  p <- ggplot(d, aes(time_s, .data[[lead]])) +
    geom_line(linewidth = 0.3) +
    labs(title = paste0("ECG — ", rec, " (lead ", lead, ")"),
         x = "Time (s)", y = "Amplitude (mV)") +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank())
  ggplotly(p, tooltip = c("x", "y"))
}

# Interactive annotated PQRST (first full beat of the clean record)
annotated_beat <- function(df, rec = CLEAN_REC, lead = "MLII") {
  d <- df %>% filter(record == rec, time_s >= 0.0, time_s <= 1.0)
  # anchor annotations to the actual R-peak so labels land correctly on real data
  r_idx  <- which.max(d[[lead]])
  r_time <- d$time_s[r_idx]
  p <- ggplot(d, aes(time_s, .data[[lead]])) +
    geom_line(linewidth = 0.4) +
    labs(title = paste0("Annotated PQRST — ", rec),
         x = "Time (s)", y = "Amplitude (mV)") +
    theme_minimal(base_size = 11)
  ggplotly(p, tooltip = c("x", "y")) %>%
    add_annotations(x = r_time - 0.16, y = 0.15,               text = "P",   showarrow = FALSE, font = list(size = 13)) %>%
    add_annotations(x = r_time,        y = max(d[[lead]]) * 1.05, text = "QRS", showarrow = FALSE, font = list(size = 13)) %>%
    add_annotations(x = r_time + 0.22, y = 0.28,               text = "T",   showarrow = FALSE, font = list(size = 13))
}

# R-peak detection (simple threshold + refractory period) 
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

# QA routine: returns one row per record 
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
    # (c) Excessive noise: large sample-to-sample differences.
    #     Real MIT-BIH signals are noisier than synthetic data, so 0.15 over-flags;
    #     0.25 separates record 108's genuine artefact from clean record 100.
    if (sd(diff(sig), na.rm = TRUE) > 0.25) {
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

# Run QA across all records 
qa_summary <- ecg %>%
  group_split(record) %>%
  map_dfr(qa_record)

print(qa_summary)

# Save outputs 
out_dir <- file.path(BASE, "outputs")
dir.create(out_dir, showWarnings = FALSE)
write_csv(qa_summary, file.path(out_dir, "qa_summary.csv"))

# Interactive plots: save as self-contained HTML (open in any browser)
htmlwidgets::saveWidget(annotated_beat(ecg),
                        file.path(out_dir, "annotated_beat.html"), selfcontained = TRUE)
walk(unique(ecg$record), function(r) {
  htmlwidgets::saveWidget(plot_record(ecg, r),
                          file.path(out_dir, paste0("wave_", r, ".html")), selfcontained = TRUE)
})

message("QA complete. Interactive plots + qa_summary.csv saved to outputs/")