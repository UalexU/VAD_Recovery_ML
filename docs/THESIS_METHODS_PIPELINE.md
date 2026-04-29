# Thesis Methods Pipeline (WinterModel)

## 1) Objective and System Context
This pipeline is designed to generate synthetic cardiovascular patient data from a Simulink-based heart-pump model, transform raw signals into physiologically meaningful features, and train/evaluate machine learning classifiers for condition prediction (`Failing`, `Recovery`, `Normal`).

The full production flow is:
1. Define sampling strategy in 4D parameter space (`Emax`, `RPM`, `Afterload`, `Preload`).
2. Run simulation jobs and save each result as an individual `.mat` file.
3. Extract and store domain features and selected raw signals.
4. Compile all successful jobs into a master ML dataset (`CSV`/`MAT`).
5. Optionally generate noisy variants for robustness studies.
6. Train and evaluate models (single models and/or weighted soft-voting ensemble).

---

## 2) Why This Architecture Was Chosen
### Per-job `.mat` outputs instead of one monolithic run file
- **Reason**: fault tolerance and distributed execution.
- Each simulation point is independent, so each job is saved as `Result_<ID>.mat`.
- Multiple computers can work on the same shared folder with collision-resistant behavior (`skip if file exists`).
- Post-processing is traceable: any row in the final CSV can be mapped back to a specific result file and raw signal set.

### Two-stage build/compile separation
- **Build step**: simulation + feature extraction + raw signal capture.
- **Compile step**: assemble final dataset from all individual results.
- **Reason**: cleaner recovery from crashes, easier QC, and reproducible incremental updates.

---

## 3) Parameter Space and Physiological Meaning
The production dataset varies four independent inputs:
- `Emax`: ventricular contractility (heart strength proxy).
- `RPM`: pump speed.
- `Afterload`: systemic resistance gain (`Rsp_Gain_Factor`, coupled with `Rep_Gain_Factor`).
- `Preload`: venous unstressed volume gain (`Vusv_Gain_Factor`).

### Why `Vusv` for preload
`Vusv` is closer to the physiological mechanism controlling venous return and filling pressure than simply changing total blood volume. This improves interpretability of preload sensitivity in extracted features.

---

## 4) Sampling Strategies Implemented
Three builders are available:

1. **Grid sweep** (`Build_ML_Database.m`)
   - Deterministic, full-factorial design.
   - Best for controlled axis-wise interpretation and response surfaces.

2. **Uniform Monte Carlo** (`MonteCarlo_Build_ML_Database.m`)
   - Random i.i.d. samples in a 4D hyper-rectangle.
   - Best for broad stochastic coverage at moderate run budgets.

3. **Latin Hypercube Sampling (LHS)** (`LH_Build_ML_Database.m`)
   - Space-filling design with `lhsdesign(..., 'Criterion','maximin')`.
   - Best for uniform marginal coverage and improved 4D fill efficiency per sample.

### Why LHS maximin was chosen for 4D
At 4 dimensions, MATLAB `lhsdesign` with maximin criterion is typically strong enough without requiring external algorithms (e.g., LHSMDU). It gives good spacing and is easy to reproduce in MATLAB-only workflows.

---

## 5) Distributed Execution and Resume Logic
Each builder follows the same execution pattern:
- Construct job list with unique IDs.
- Shuffle job order per session (reduces multi-PC contention).
- For each job:
  - If `Result_*.mat` or `ERROR_*.txt` exists: skip.
  - Else run simulation, extract features, save output.

### Failure handling
- Build scripts log runtime errors per job (`ERROR_*.txt`).
- `Retry_Failed_Simulations.m` re-attempts missing points and can write NaN placeholders for persistent failures.
- This prevents infinite retry loops and enables deterministic compile behavior.

---

## 6) Signal Extraction and Feature Engineering
Core extraction logic is in `modules/extractOscillometric.m`.

### Pressure-domain features
- `H1`, `H2`: first and second harmonics from cuff-pressure-derived signal (FFT-based via `getFFT`).
- `MAP`, `SBP`, `DBP`: oscillometric pressure metrics (`Oscillometric.m`).

### Pump-flow features
- `PumpFlow`: pulsatility metric from trimmed flow signal (peak-to-peak style with peak detection fallback).
- `dPumpFlow`: pulsatility metric from numerically derived and filtered `dQ/dt`.

### Derivative harmonics (added for preload sensitivity)
- `dQ_H1`, `dQ_H2`: first and second harmonics of trimmed `dQ/dt`.
- **Rationale**: derivative-domain harmonics capture waveform shape/rate-of-change information not fully represented by amplitude-only metrics.

### Derivative method details
`dQ/dt` is computed numerically from trimmed `Qpump`:
- `dQ_numeric = [0; diff(Q_trim)] / Ts`
- Low-pass filtered with 3rd-order Butterworth at 20 Hz using `filtfilt` (zero-phase).

This combination reduces high-frequency differentiation noise while preserving physically relevant pulsatile structure.

---

## 7) Raw Signal Retention Policy
Each result file stores selected raw signals:
- `Signals.P`
- `Signals.P_all`
- `Signals.Qpump`
- `Signals.Psa`

### Why raw signals are retained
- Enables later recalculation of features without rerunning simulation.
- Supports noise-injection studies directly on signal level.
- Allows auditability and methodological transparency for publication.

---

## 8) Dataset Compilation
### Standard compiler
- `Compile_Master_Database.m` aggregates `Result_*.mat` into:
  - `ML_Master_Database.csv`
  - `ML_Master_Database.mat`

### LHS-specific compiler
- `Compile_LH_Database.m` aggregates `Result_LH_*.mat` into LHS-specific outputs.

### Labeling
Condition labels are thresholded from `Emax`:
- `0`: Failing
- `1`: Recovery
- `2`: Normal

This label policy is embedded at compile stage for consistent downstream training.

---

## 9) Noise and Robustness Pipeline
`Generate_Noisy_Database.m` creates noisy datasets from stored raw results.

Design principles:
- Inject noise at signal level where possible (`Qpump`, cuff/pressure signals).
- Recompute derived features from noisy signals.
- Preserve clean-vs-noisy dataset separation (no overwrite).

This supports sensitivity and robustness analyses required for translational ML claims.

---

## 10) Model Training and Ensemble Inference
### Single-model training
Models can be trained in MATLAB workflows (including Classification Learner exports) using compiled datasets.

### Weighted soft voting
`Soft_voting_classification.m` combines probability outputs from top models:
- For model `i`, multiply class-probability vector by model weight (often validation accuracy).
- Sum weighted probabilities across models.
- Normalize by total weight.
- Predict class with max normalized score.

**Reason for weighted voting**: allows stronger models to contribute proportionally more than weaker models.

---

## 11) Quality Control and Debug Utilities
- `Inspect_Single_Result.m`: inspect one `.mat` result (inputs, features, raw signal plots).
- This is used to verify extraction correctness and detect malformed or failed outputs early.

---

## 12) Reproducibility Notes
To ensure reproducible thesis results:
- Fix and record random seeds for MC/LHS job generation.
- Version-control scripts and document parameter ranges.
- Keep raw result folder immutable once a dataset version is finalized.
- Export final model artifacts with clear naming and date/version tags.

---

## 13) Practical Method Statement (short form)
In this work, we generated a synthetic cardiovascular dataset by sampling a 4D physiological-control space (`Emax`, `RPM`, `Afterload`, `Preload`) and running independent Simulink simulations per sampled point. Each simulation produced engineered oscillometric and pump-flow features, including FFT harmonics and derivative-domain pulsatility metrics, while preserving selected raw signals for auditability and robustness testing. A distributed, file-based execution strategy enabled resume-safe multi-computer production. Individual result files were compiled into ML-ready master datasets with condition labels derived from `Emax`. Additional noisy variants were generated by perturbing raw signals and recomputing features. Final classification experiments included both single-model and weighted soft-voting ensemble inference.

