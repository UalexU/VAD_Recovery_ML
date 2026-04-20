# WinterModel Development Log (Concise)

## Goal
Build a reproducible MATLAB simulation pipeline that generates ML-ready datasets for heart recovery classification from 4D parameter variation:
- `Emax`
- `RPM`
- `Afterload` (`Rsp/Rep` gain)
- `Preload` (`Vusv` gain)

## Core Design Decisions
- Use `Vusv_Gain_Factor` for preload sweeps (physiologically cleaner than direct total volume sweeps).
- Save per-simulation outputs as individual `Result_*.mat` files for traceability and distributed execution.
- Use skip-if-exists logic (`isfile`) to support resume, crash recovery, and multi-computer execution.
- Keep a separate compile step to build master CSV/MAT from all individual results.
- Store raw signals (`P`, `P_all`, `Qpump`) for post-processing and synthetic noise injection.

## Folder Organization (Current)
- `ML_Pipeline/` -> database builders, compilers, ML utilities
- `Data_Collection_Scripts/` -> standard sweep scripts
- `modules/` -> shared extraction/signal-processing helpers
- `Legacy_Scripts/` -> old scripts kept for reference
- `Data/` -> generated outputs (ignored in git)

## Key Pipeline Evolution

### 1) Feature extraction unification
- `modules/extractOscillometric.m`
  - Pump features standardized to pulsatility (peak-to-peak style):
    - `O.Qpump`
    - `O.dQpump`
  - `dQ/dt` switched to numerical derivative from `Qpump` plus 3rd-order 20 Hz low-pass Butterworth (`filtfilt`).
  - Added FFT harmonics from `dQ`:
    - `O.dQ_H1`
    - `O.dQ_H2`
  - Fixed function bug where `dQ` FFT was previously outside function scope.
  - Added compatibility for `Qpump` as matrix or `timeseries`.

### 2) Build scripts expanded and aligned
- `ML_Pipeline/Build_ML_Database.m`
- `ML_Pipeline/MonteCarlo_Build_ML_Database.m`
- `ML_Pipeline/LH_Build_ML_Database.m`

All now save:
- Inputs: `Emax`, `RPM`, `AL`, `PL`
- Features:
  - `FFT_H1`, `FFT_H2`
  - `PumpFlow`, `dPumpFlow`
  - `dQ_H1`, `dQ_H2`
  - `MAP`, `SBP`, `DBP`
- Raw signals:
  - `Signals.P`
  - `Signals.P_all`
  - `Signals.Qpump`
  - `Signals.Psa`

### 3) Emax strategy updates
- Transitioned from coarse fixed bands to tolerance-zone-based ranges.
- Updated to 30% tolerance design and refined step-size choices during iteration.

### 4) Distributed robustness
- Build scripts check existing `Result_*.mat` or `ERROR_*.txt` and skip completed jobs.
- `ML_Pipeline/Retry_Failed_Simulations.m` retries missing jobs and writes NaN "ghost" outputs for persistent failures.

### 5) Latin Hypercube support
- Added dedicated `ML_Pipeline/LH_Build_ML_Database.m`.
- Uses `lhsdesign(..., 'Criterion','maximin')` for 4D space-filling.
- Added two-phase run mode:
  1. Generate shared LH job list once.
  2. Run simulations on many PCs loading the same list.
- Important: do **not** split LH into independent 15k+15k runs if target is one coherent 30k LHS design.

### 6) Compilation and inspection utilities
- `ML_Pipeline/Compile_Master_Database.m` updated for expanded feature set (`dQ_H1`, `dQ_H2`).
- Added `ML_Pipeline/Compile_LH_Database.m` to compile `Result_LH_*.mat` outputs separately.
- Added `ML_Pipeline/Inspect_Single_Result.m` to inspect one file quickly (features + signal plots).
  - Updated to handle `P_all` as `timeseries`.

### 7) Noise-data generation
- `ML_Pipeline/Generate_Noisy_Database.m` uses saved raw signals to create noisy derived features.
- Updated for signal-format compatibility where needed (matrix/timeseries handling logic).

## Current Standard Workflow
1. Run one builder:
   - Grid: `Build_ML_Database.m`
   - Uniform MC: `MonteCarlo_Build_ML_Database.m`
   - LHS: `LH_Build_ML_Database.m`
2. If needed, run `Retry_Failed_Simulations.m`.
3. Compile:
   - Grid/MC -> `Compile_Master_Database.m`
   - LHS -> `Compile_LH_Database.m`
4. Optional:
   - Single-file QA -> `Inspect_Single_Result.m`
   - Noisy dataset -> `Generate_Noisy_Database.m`

## Practical Notes
- `Oscillometric.m` must remain in `modules/` (extractor dependency).
- `.gitignore` excludes generated simulation/cache outputs (`Data/`, `slprj/`, `*.slxc`, etc.).
- Shared-drive runs require identical script config and paths across machines.

## Next Suggested Improvements
- Add one global config file for shared paths/ranges to avoid drift across scripts.
- Add a lightweight validation script that checks one random result file schema before long runs.
- Add version tag in each `Result_*.mat` (`result.Meta.SchemaVersion`) for future-proof compilers.
