# Benchmark R-peak detection against expert annotations (MIT-BIH record 100).
# Produces sensitivity + PPV for a baseline (global-threshold) detector and an (moving-window) detector.

library(tidyverse)
FS <- 360

sig <- read_csv("D:/ECG QA VALIDATION/DATA/ecg_100_full.csv",    show_col_types = FALSE)
ann <- read_csv("D:/ECG QA VALIDATION/DATA/annotations_100.csv", show_col_types = FALSE)
x     <- sig[["MLII"]]
truth <- ann$sample

# Detector 1: global threshold (60% of whole-record max) + 200ms refractory 
detect_global <- function(x, fs, frac = 0.6) {
  thr <- frac * max(x, na.rm = TRUE)
  idx <- which(x > thr)
  peaks <- integer(0); last <- -1e9; refr <- as.integer(0.2 * fs)
  for (i in idx) if (i - last > refr) { peaks <- c(peaks, i); last <- i }
  peaks
}

# Detector 2: moving-window threshold (55% of LOCAL max in a 2s window) 
detect_local <- function(x, fs, win_s = 2.0, frac = 0.55) {
  w <- as.integer(win_s * fs); refr <- as.integer(0.2 * fs)
  n <- length(x); peaks <- integer(0); last <- -1e9
  for (i in seq_len(n)) {
    lo <- max(1, i - w %/% 2); hi <- min(n, i + w %/% 2)
    if (x[i] > frac * max(x[lo:hi]) && (i - last) > refr) {
      lo2 <- max(1, i - refr); hi2 <- min(n, i + refr)
      if (x[i] == max(x[lo2:hi2])) { peaks <- c(peaks, i); last <- i }
    }
  }
  peaks
}

# Matching: greedy nearest within 50ms tolerance 
match_beats <- function(peaks, truth, fs, tol_s = 0.05) {
  tol <- as.integer(tol_s * fs)
  matched <- rep(FALSE, length(truth)); TP <- 0L
  for (d in peaks) {
    j <- which.min(abs(truth - d))
    if (abs(truth[j] - d) <= tol && !matched[j]) { TP <- TP + 1L; matched[j] <- TRUE }
  }
  FP <- length(peaks) - TP; FN <- length(truth) - TP
  tibble(detected = length(peaks), TP = TP, FP = FP, FN = FN,
         sensitivity = round(TP/(TP+FN), 4), PPV = round(TP/(TP+FP), 4))
}

res_global <- match_beats(detect_global(x, FS), truth, FS) |> mutate(detector = "Global threshold (baseline)", .before = 1)
res_local  <- match_beats(detect_local(x, FS),  truth, FS) |> mutate(detector = "Moving-window (improved)",   .before = 1)

validation <- bind_rows(res_global, res_local) |> mutate(expert_beats = length(truth), .after = detector)
print(validation)

dir.create("D:/ECG QA VALIDATION/outputs", showWarnings = FALSE)
write_csv(validation, "D:/ECG QA VALIDATION/outputs/validation_100.csv")
message("Saved outputs/validation_100.csv")
