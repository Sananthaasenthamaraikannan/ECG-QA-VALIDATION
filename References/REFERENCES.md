# References — ECG Data Exploration

## 1. Data source 

**MIT-BIH Arrhythmia Database — dataset**
Moody GB, Mark RG. *The impact of the MIT-BIH Arrhythmia Database.*
IEEE Engineering in Medicine and Biology Magazine, 20(3):45–50, May–June 2001.
DOI: 10.1109/51.932724 · PMID: 11446209

**PhysioNet — hosting platform / standard citation**
Goldberger AL, Amaral LAN, Glass L, Hausdorff JM, Ivanov PC, Mark RG, Mietus JE,
Moody GB, Peng C-K, Stanley HE. *PhysioBank, PhysioToolkit, and PhysioNet:
Components of a New Research Resource for Complex Physiologic Signals.*
Circulation, 101(23):e215–e220, 2000.

Database landing page: https://physionet.org/content/mitdb/1.0.0/

---

## 2. Software / tools 

- **wfdb (Python)** — reader for PhysioNet WFDB-format recordings.
  https://github.com/MIT-LCP/wfdb-python
- **R** and the **tidyverse** (readr, dplyr, ggplot2, purrr) — data handling,
  QA routine, plotting.
- **plotly / htmlwidgets** — interactive per-record traces.
- Interactive viewer (`ecg_viewer.html`) — custom HTML5 canvas + JavaScript.

(Add exact package versions with `sessionInfo()` in R and `pip show wfdb` —
see `session_info.txt` in this folder once you generate it.)

---

## 3. Regulatory / domain concepts referenced

I referred to these guidelines and concepts by name while learning. Before
citing any of them formally, confirm the exact title/version from the issuing
body — do not cite from memory.

- **ICH E14** — guideline on QT/QTc interval prolongation and proarrhythmic
  potential for non-antiarrhythmic drugs. Confirm current version at:
  https://www.ich.org  (look for the E14 guideline and any Q&A updates).
- **ICH E6 (GCP)** — Good Clinical Practice. Confirm version (E6(R2)/E6(R3))
  at https://www.ich.org before citing.
- **ALCOA+ data-integrity principles** — widely used in GxP data integrity.
  Confirm against a regulator source (e.g., MHRA or FDA data-integrity
  guidance) rather than a blog before citing.

---

## 4. Physiology reference ranges

The PR/QRS/QT/QTc reference ranges and the description of the PQRST complex in
my report were written from general knowledge as a learning summary, NOT taken
from a specific cited source. They are approximately standard, but ranges vary
by source, sex, age, and QT-correction formula.

- A standard clinical ECG textbook (e.g., a widely used "ECG made easy"/
  "rapid interpretation"-type reference) for PQRST morphology and interval ranges.

---
