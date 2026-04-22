%% ============================================================
%   PROCESS MASTER CSV
%   Loads a compiled ML master CSV (from Compile_*_Database.m), cleans
%   rows, refreshes Condition from Emax if needed, and saves processed
%   CSV + MAT for training or downstream analysis.
% ============================================================

clc; close all;

%% --- USER: input / output paths ---
% Full path to the CSV from Compile_Master_Database.m or Compile_LH_Database.m.
% Examples: .../ML_Master_Database_LH.csv  or  .../ML_Master_Database.csv
INPUT_CSV = '';  % empty => use SHARED_DRIVE_PATH below + DEFAULT_LH_CSV, or local Data/ML_Database_LH if path empty

SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\Trained Models\CSV Simulation Files';  % set [] to use ../Data/ML_Database_LH/
DEFAULT_LH_CSV    = 'ML_Master_Database_Noisy10_OptionB.csv';  % change to ML_Master_Database.csv if using the MC compile output
OUTPUT_CSV_SUFFIX = '_processed';
SAVE_MAT          = true;

%% Expected schema (must match Compile_*_Database.m)
feature_cols = {'Emax', 'RPM', 'Afterload', 'Preload', ...
    'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', ...
    'dQ_H1', 'dQ_H2', ...
    'MAP', 'SBP', 'DBP'};

%% Resolve input path
if isempty(INPUT_CSV)
    if isempty(SHARED_DRIVE_PATH)
        db_folder = fullfile('..', 'Data', 'ML_Database_LH');
        input_csv = fullfile(db_folder, DEFAULT_LH_CSV);
    else
        input_csv = fullfile(SHARED_DRIVE_PATH, DEFAULT_LH_CSV);
    end
else
    input_csv = INPUT_CSV;
end

if ~isfile(input_csv)
    error('CSV not found: %s', input_csv);
end

fprintf('Reading: %s\n', input_csv);

T = readtable(input_csv);

%% Validate columns
missing = setdiff(feature_cols, T.Properties.VariableNames);
if ~isempty(missing)
    error('CSV missing columns: %s', strjoin(missing, ', '));
end

n_in = height(T);
fprintf('Rows read: %d\n', n_in);

%% Clean: drop rows with NaN/Inf in feature columns
X = table2array(T(:, feature_cols));
bad = any(~isfinite(X), 2);
n_bad = sum(bad);
if n_bad > 0
    fprintf('Dropping %d rows with NaN/Inf in feature columns.\n', n_bad);
    T = T(~bad, :);
end

%% Condition from Emax (same rule as Compile_*_Database.m; overwrites CSV label if present)
emax = T.Emax;
cond_num = zeros(height(T), 1);
cond_num(emax >= 0.25 & emax < 0.6) = 1;
cond_num(emax >= 0.6) = 2;

% Export Condition as text labels:
%   0 -> Failure, 1 -> Recovery, 2 -> Normal
cond_text = strings(height(T), 1);
cond_text(cond_num == 0) = "Failure";
cond_text(cond_num == 1) = "Recovery";
cond_text(cond_num == 2) = "Normal";
T.Condition = cond_text;

%% Drop exact duplicate feature rows (keep first occurrence)
if height(T) > 1
    X2 = table2array(T(:, feature_cols));
    [~, ia_first] = unique(X2, 'rows', 'stable');
    keep = false(height(T), 1);
    keep(ia_first) = true;
    n_dup = sum(~keep);
    if n_dup > 0
        fprintf('Dropping %d duplicate feature rows (keeping first occurrence).\n', n_dup);
        T = T(keep, :);
    end
end

%% Column order: features then Condition
out_cols = [feature_cols, {'Condition'}];
T_out = T(:, out_cols);

if height(T_out) == 0
    error('No rows left after cleaning (check CSV and NaN handling).');
end

%% Output paths
[pdir, pbase, ~] = fileparts(input_csv);
out_csv = fullfile(pdir, [pbase, OUTPUT_CSV_SUFFIX, '.csv']);
writetable(T_out, out_csv);
fprintf('Wrote: %s (%d rows x %d cols)\n', out_csv, height(T_out), width(T_out));

if SAVE_MAT
    ML_Table = T_out;
    out_mat = fullfile(pdir, [pbase, OUTPUT_CSV_SUFFIX, '.mat']);
    save(out_mat, 'ML_Table', '-v7.3');
    fprintf('Wrote: %s\n', out_mat);
end

%% Summary
fprintf('\n--- Processed summary ---\n');
fprintf('Rows in  -> out: %d -> %d\n', n_in, height(T_out));
fprintf('Condition Failure:  %d\n', sum(strcmp(string(T_out.Condition), "Failure")));
fprintf('Condition Recovery: %d\n', sum(strcmp(string(T_out.Condition), "Recovery")));
fprintf('Condition Normal:   %d\n', sum(strcmp(string(T_out.Condition), "Normal")));

fprintf('\n--- Feature ranges (processed) ---\n');
for c = 1:numel(feature_cols)
    name = feature_cols{c};
    v = T_out.(name);
    fprintf('  %-12s  min=%12.4g  max=%12.4g  mean=%12.4g\n', ...
        name, min(v), max(v), mean(v));
end

fprintf('\nDone.\n');
