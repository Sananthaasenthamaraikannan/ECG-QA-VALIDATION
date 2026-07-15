## ECG Data Exploration

A small project where I take real clinical ECG recordings, learn what a data reviewer
actually checks, and build a reproducible quality-control workflow in R — then test my own
beat detector against beats labelled by cardiologists.

I'm a Health Data Science master's student with a background in statistics and R. I had
almost no cardiology background when I started this, so I've tried to be honest throughout
about what I understood well and what I had to look up. This is a data-quality project,
not clinical diagnosis — it's about the data, not the patient.


## Why?

In drug trials, ECGs are collected mainly to watch for cardiac safety problems, especially
whether a drug lengthens the QT interval (there's a regulatory guideline, ICH E14, about
this). A central ECG lab receives recordings from many trial sites, and data processors check
that each recording is complete, correctly labelled, and good enough quality before the
measurements are trusted. I wanted to understand and reproduce that checking step, and to see
whether the data-science skills I already have transfer to clinical ECG data.


## What is this exploration about

Loads real two-lead ECG recordings (MIT-BIH, 360 Hz).
Plots the signal and labels one heartbeat (P wave, QRS complex, T wave) so the theory
is visible.
Runs a QA routine that flags lead dropout, flatline segments, excessive noise, and
physiologically implausible heart rates.
Validates a simple R-peak detector against 2,273 cardiologist-labelled beats, reporting
sensitivity and precision.
Ships an interactive viewer so you can scroll the trace and compare detectors visually.



## the findings

I benchmarked R-peak detection against the expert beat labels for record 100, matching each
detected peak to a labelled beat within 50 ms:

DetectorSensitivityPrecision (PPV)Missed beatsGlobal threshold (my first attempt)81.8%99.95%413Moving-window (improved)99.91%99.96%2

My first detector used one fixed threshold for the whole recording. It was very precise but
missed 413 beats — because the signal amplitude drifts over the 30 minutes, and a single
threshold set from the whole-record maximum sits too high during the quieter stretches. Once I
understood that, I switched to a moving-window threshold that adapts to the local signal, which
recovered almost all the missed beats. Diagnosing why the first version failed, then fixing
it, was the most useful part of the project.


## a finding i didnt plan

I deliberately included one clean recording (record 100) and one noisy one (record 108). The
noisy record got flagged — but not by the noise check directly. It surfaced as an impossible
heart rate (~21 bpm). When I looked into why, it made sense: the noise disrupts beat detection,
which then produces a nonsense heart-rate estimate. So a problem in the raw signal quietly
became a wrong number downstream. That felt like a genuinely useful lesson: a suspicious value
isn't always wrong at that value — sometimes it's a symptom of a data-quality problem further
up, and a reviewer who just "fixed" the number would miss the real issue.


## Repository structure

.
├── ECG_DATAEXPORT.py       # pulls MIT-BIH records from PhysioNet (via wfdb)
├── ecg_qa.R                # QA routine + interactive plots
├── validation.R            # R-peak detection + validation against expert beats
├── Report.Rmd              # full write-up (knits to Report.html)
├── ECG_Viewer.html         # interactive trace + detector comparison
├── DATA/                   # ecg_data.csv, annotations_100.csv
│                           # (ecg_100_full.csv is regenerated, not committed)
├── outputs/                # qa_summary.csv, validation_100.csv, plots
└── References/             # REFERENCES.md, references.bib


## How to reproduce

1. Pull the data (Python, one-time):

bashpip install wfdb pandas
python ECG_DATAEXPORT.py

This writes the CSVs into DATA/. The full 30-minute signal (ecg_100_full.csv, ~650k rows)
is regenerated here and intentionally kept out of the repo to avoid committing a large file.

2. Run the analysis (R):

rinstall.packages(c("tidyverse", "plotly", "htmlwidgets", "rmarkdown"))
source("ecg_qa.R")        # QA routine + interactive plots
source("validation.R")    # validation metrics (note: the moving-window
                          # detector loops over 650k samples, so it's slow)

3. Build the report:

rrmarkdown::render("Report.Rmd")

4. Open ECG_Viewer.html in a browser for the interactive version.


What I'd flag about my own work

I want to be honest about the limits:


My beat detector is deliberately simple. Real ECG labs use validated algorithms and still
have a human check the output. This is a learning exercise, not production-grade.
I discuss the PR/QT/QTc intervals but don't actually measure them from the signal — a real
workflow would bring those in from validated measurements.
I tuned the improved detector's settings on record 100 and didn't test them on other records,
so I can't claim they generalise. That's what I'd test next.


One habit I tried to build early: clinical data work follows data-integrity principles (I came
across "ALCOA+"). My outputs are attributable and dated, the scripts make everything
reproducible, and QA flags never overwrite the raw signal — the original data stays intact and
the review is logged separately.


## Data and references

Data: MIT-BIH Arrhythmia Database (Moody & Mark, 2001), via PhysioNet (Goldberger et
al., 2000). PhysioNet asks that both be cited when the database is used. Records used: 100
(clean) and 108 (noisy); record 100's expert annotations were used for validation. Full details
in References/REFERENCES.md.


Sananthaa Senthamaraikannan — MSc Health Data Science. Companion to my
Understanding CDISC repository.
