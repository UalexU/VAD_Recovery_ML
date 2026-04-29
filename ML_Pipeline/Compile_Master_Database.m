%% ============================================================
%   COMPILE MASTER DATABASE
%
%   Pipeline role:
%     1. Load every Result_*.mat from the simulation folder.
%     2. QC gate: exclude corrupted files and suction cases.
%     3. Save clean master dataset (CSV + MAT).
%     4. Save AcceptedFiles.mat so Generate_Noisy_Database.m
%        only processes QC-approved simulations.
%     5. Write QC_Exclusion_Log.csv documenting every exclusion.
%
%   Run order:
%     Build_ML_Database.m  -->  Compile_Master_Database.m  -->  Generate_Noisy_Database.m
% ============================================================

clc; close all;

%% Setup
addpath('..');
addpath(genpath('../modules'));

SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\';

if isempty(SHARED_DRIVE_PATH)
    db_folder = fullfile('Data', 'ML_Database');
else
    db_folder = SHARED_DRIVE_PATH;
end

sim_folder  = fullfile(db_folder, 'simulations_30');
clean_csv   = fullfile(db_folder, 'ML_Master_Database_Clean.csv');
clean_mat   = fullfile(db_folder, 'ML_Master_Database_Clean.mat');
accepted_mat = fullfile(db_folder, 'AcceptedFiles.mat');   % consumed by Generate_Noisy_Database
exclusion_log = fullfile(db_folder, 'QC_Exclusion_Log.csv');

if ~exist(sim_folder, 'dir')
    error('Simulation folder not found: %s', sim_folder);
end

%% Scan Files
files = dir(fullfile(sim_folder, 'Result_*.mat'));
num_files = length(files);
fprintf('Found %d result files.\n', num_files);

err_files = dir(fullfile(sim_folder, 'ERROR_*.txt'));
fprintf('Found %d error files (already failed at build time).\n\n', length(err_files));

if num_files == 0
    error('No results found. Run Build_ML_Database.m first.');
end

%% Suction Detection Parameters
PLV_MIN_THRESHOLD  = 0;    % mmHg — Plv below this = suction
STEADY_STATE_FRAC  = 0.5;  % Use last 50% of signal as steady-state window
QPUMP_NEG_FRACTION = 0.05; % Proxy: if >5% of trimmed Qpump samples are negative → flag

%% Column Definitions
col_names = {'Emax', 'RPM', 'Afterload', 'Preload', ...
             'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', ...
             'dQ_H1', 'dQ_H2', ...
             'MAP', 'SBP', 'DBP'};
num_cols = length(col_names);

%% QC Loop
all_rows       = NaN(num_files, num_cols);
accepted_files = {};   % paths of QC-passed files
exclusion_rows = {};   % log entries

fprintf('Running QC + compile...\n');
t_start = tic;

for i = 1:num_files
    filepath = fullfile(files(i).folder, files(i).name);
    fname    = files(i).name;

    %% --- Gate 1: Load & field check ---
    try
        data = load(filepath);
    catch
        exclusion_rows{end+1} = {fname, 'CORRUPT', 'File could not be loaded'};
        fprintf('  [EXCLUDED - corrupt]   %s\n', fname);
        continue;
    end

    if ~isfield(data, 'Inputs') || ~isfield(data, 'Features')
        exclusion_rows{end+1} = {fname, 'MISSING_FIELDS', 'Inputs or Features struct absent'};
        fprintf('  [EXCLUDED - fields]    %s\n', fname);
        continue;
    end

    %% --- Gate 2: Suction detection ---
    isSuction  = false;
    suctionReason = '';

    % Priority 1: Plv_log stored directly in Signals
    if isfield(data, 'Signals') && isfield(data.Signals, 'Plv')
        [isSuction, sInfo] = detectSuctionFromSim(data.Signals.Plv, ...
            'PlvMinThreshold', PLV_MIN_THRESHOLD, ...
            'SteadyStateFrac', STEADY_STATE_FRAC);
        if isSuction, suctionReason = sInfo.reason; end

    % Priority 2: Legacy Plv_log at top level
    elseif isfield(data, 'Plv_log')
        [isSuction, sInfo] = detectSuctionFromSim(data.Plv_log, ...
            'PlvMinThreshold', PLV_MIN_THRESHOLD, ...
            'SteadyStateFrac', STEADY_STATE_FRAC);
        if isSuction, suctionReason = sInfo.reason; end

    % Priority 3: Qpump proxy (negative flow fraction)
    elseif isfield(data, 'Signals') && isfield(data.Signals, 'Qpump')
        if isa(data.Signals.Qpump, 'timeseries')
            Q_raw = data.Signals.Qpump.Data;
        else
            Q_raw = data.Signals.Qpump(:, 2);
        end
        N = length(Q_raw);
        Q_trim = Q_raw(round(N * STEADY_STATE_FRAC):end);
        neg_frac = mean(Q_trim < 0);
        if neg_frac > QPUMP_NEG_FRACTION
            isSuction = true;
            suctionReason = sprintf('Qpump proxy: %.1f%% negative samples in steady-state', neg_frac*100);
        end
    end

    if isSuction
        exclusion_rows{end+1} = {fname, 'SUCTION', suctionReason};
        fprintf('  [EXCLUDED - suction]   %s  (%s)\n', fname, suctionReason);
        continue;
    end

    %% --- Gate 3: NaN feature check ---
    try
        row = [ ...
            data.Inputs.Emax, data.Inputs.RPM, data.Inputs.AL, data.Inputs.PL, ...
            data.Features.FFT_H1, data.Features.FFT_H2, ...
            data.Features.PumpFlow, data.Features.dPumpFlow, ...
            data.Features.dQ_H1, data.Features.dQ_H2, ...
            data.Features.MAP, data.Features.SBP, data.Features.DBP];
    catch ME
        exclusion_rows{end+1} = {fname, 'MISSING_FEATURE', ME.message};
        fprintf('  [EXCLUDED - feature]   %s (%s)\n', fname, ME.message);
        continue;
    end

    if any(isnan(row))
        exclusion_rows{end+1} = {fname, 'NAN_FEATURE', 'Row contains NaN values'};
        fprintf('  [EXCLUDED - NaN]       %s\n', fname);
        continue;
    end

    %% --- Passed all gates ---
    all_rows(i, :)  = row;
    accepted_files{end+1} = filepath;

end

%% Assemble Clean Table
valid_idx  = ~isnan(all_rows(:, 1));
clean_rows = all_rows(valid_idx, :);

ML_Table = array2table(clean_rows, 'VariableNames', col_names);

% Assign string labels for Condition
Condition = strings(height(ML_Table), 1);
Condition(ML_Table.Emax < 0.25) = "Failure";
Condition(ML_Table.Emax >= 0.25 & ML_Table.Emax < 0.6) = "Recovery";
Condition(ML_Table.Emax >= 0.6) = "Normal";
ML_Table.Condition = categorical(Condition);

%% Save Outputs
writetable(ML_Table, clean_csv);
save(clean_mat, 'ML_Table');

% Save accepted file list for Generate_Noisy_Database.m
save(accepted_mat, 'accepted_files');

% Write exclusion log
if ~isempty(exclusion_rows)
    ExclusionTable = cell2table(exclusion_rows, ...
        'VariableNames', {'File', 'Reason', 'Detail'});
    writetable(ExclusionTable, exclusion_log);
    fprintf('\nExclusion log saved: %s (%d entries)\n', exclusion_log, height(ExclusionTable));
else
    fprintf('\nNo exclusions. All files passed QC.\n');
end

elapsed = toc(t_start);
fprintf('\n=== Compile Complete (%.1fs) ===\n', elapsed);
fprintf('  Total scanned  : %d\n', num_files);
fprintf('  Accepted (clean): %d\n', numel(accepted_files));
fprintf('  Excluded        : %d\n', numel(exclusion_rows));
fprintf('  Clean CSV       : %s\n', clean_csv);
fprintf('  Accepted list   : %s\n', accepted_mat);

fprintf('\n--- Class Distribution ---\n');
fprintf('  Failure  : %d\n', sum(ML_Table.Condition == "Failure"));
fprintf('  Recovery : %d\n', sum(ML_Table.Condition == "Recovery"));
fprintf('  Normal   : %d\n', sum(ML_Table.Condition == "Normal"));

fprintf('\n--- Feature Ranges ---\n');
for c = 5:length(col_names)
    vals = clean_rows(:, c);
    fprintf('  %-12s  min=%8.3f  max=%8.3f  mean=%8.3f\n', ...
        col_names{c}, min(vals), max(vals), mean(vals));
end
