%% ============================================================
%   COMPILE LATIN HYPERCUBE (LH) DATABASE
%   Merges individual LH simulation .mat files into one ML-ready
%   CSV and MAT file.
% ============================================================

clc; close all;

%% Setup Folders
addpath('..');
addpath(genpath('../modules'));
% --- CHANGE THIS TO YOUR SHARED DRIVE PATH ---
SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\simulations_LH'; 

if isempty(SHARED_DRIVE_PATH)
    db_folder  = fullfile('..', 'Data', 'ML_Database_LH');
    sim_folder = fullfile(db_folder, 'simulations');
else
    db_folder  = SHARED_DRIVE_PATH;
    sim_folder = SHARED_DRIVE_PATH;
end

master_csv = fullfile(db_folder, 'ML_Master_Database_LH.csv');
master_mat = fullfile(db_folder, 'ML_Master_Database_LH.mat');

if ~exist(sim_folder, 'dir')
    error('No simulation folder found at %s', sim_folder);
end

%% Get List of Result Files
files = dir(fullfile(sim_folder, 'Result_LH_*.mat'));
num_files = length(files);
fprintf('Found %d LH simulation result files.\n', num_files);

if num_files == 0
    error('No results found. Run LH_Build_ML_Database.m first.');
end

%% Suction Detection Parameters
PLV_MIN_THRESHOLD  = 0;    % mmHg — Plv below this = suction
STEADY_STATE_FRAC  = 0.5;  % Use last 50% of signal as steady-state window
QPUMP_NEG_FRACTION = 0.50; % Proxy: increased to 50% to avoid flagging high-afterload regurgitation

%% Column Definitions (Must match LH_Build_ML_Database.m)
col_names = {'Emax', 'RPM', 'Afterload', 'Preload', ...
             'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', ...
             'dQ_H1', 'dQ_H2', ...
             'MAP', 'SBP', 'DBP'};

num_cols = length(col_names);

%% Preallocate and Compile
all_rows       = NaN(num_files, num_cols);
accepted_files = {};   % paths of QC-passed files
exclusion_rows = {};   % log entries
accepted_mat   = fullfile(db_folder, 'AcceptedFiles_LH.mat');
exclusion_log  = fullfile(db_folder, 'QC_Exclusion_Log_LH.csv');

fprintf('Compiling LH database...\n');
t_start = tic;

for i = 1:num_files
    filepath = fullfile(files(i).folder, files(i).name);
    fname    = files(i).name;

    %% --- Gate 1: Load & field check ---
    try
        data = load(filepath); % Load full struct for repair check
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

    if isfield(data, 'Signals') && isfield(data.Signals, 'Plv')
        [isSuction, sInfo] = detectSuctionFromSim(data.Signals.Plv, ...
            'PlvMinThreshold', PLV_MIN_THRESHOLD, ...
            'SteadyStateFrac', STEADY_STATE_FRAC);
        if isSuction, suctionReason = sInfo.reason; end
    elseif isfield(data, 'Plv_log')
        [isSuction, sInfo] = detectSuctionFromSim(data.Plv_log, ...
            'PlvMinThreshold', PLV_MIN_THRESHOLD, ...
            'SteadyStateFrac', STEADY_STATE_FRAC);
        if isSuction, suctionReason = sInfo.reason; end
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

    %% --- AUTO-REPAIR: Missing dQ_H1/dQ_H2 ---
    if ~isfield(data.Features, 'dQ_H1') || ~isfield(data.Features, 'dQ_H2')
        if isfield(data, 'Signals') && isfield(data.Signals, 'Qpump')
            if isa(data.Signals.Qpump, 'timeseries')
                Q_raw = data.Signals.Qpump.Data;
                time_q = data.Signals.Qpump.Time;
            else
                Q_raw = data.Signals.Qpump(:, 2);
                time_q = data.Signals.Qpump(:, 1);
            end
            Ts_q = time_q(2) - time_q(1);
            
            dQ_numeric = [0; diff(Q_raw)] ./ Ts_q;
            fs_q = 1/Ts_q;
            [b, a] = butter(3, 20/(fs_q/2), 'low');
            dQ_filtered = filtfilt(b, a, dQ_numeric);
            
            start_idx = round(length(dQ_filtered) * 0.8);
            dQ_trim = dQ_filtered(start_idx:end);
            time_dQ = (0:length(dQ_trim)-1)' * Ts_q;
            
            [h1, h2] = getFFT(dQ_trim, time_dQ, false);
            
            data.Features.dQ_H1 = h1;
            data.Features.dQ_H2 = h2;
            
            save(filepath, '-struct', 'data');
            fprintf('  [Repaired] %s: Added dQ harmonics.\n', fname);
        else
            data.Features.dQ_H1 = NaN;
            data.Features.dQ_H2 = NaN;
        end
    end

    %% --- Gate 3: NaN feature check ---
    try
        row = [ ...
            data.Inputs.Emax, ...
            data.Inputs.RPM, ...
            data.Inputs.AL, ...
            data.Inputs.PL, ...
            data.Features.FFT_H1, ...
            data.Features.FFT_H2, ...
            data.Features.PumpFlow, ...
            data.Features.dPumpFlow, ...
            data.Features.dQ_H1, ...
            data.Features.dQ_H2, ...
            data.Features.MAP, ...
            data.Features.SBP, ...
            data.Features.DBP];
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

%% Clean and Save
valid_idx = ~isnan(all_rows(:, 1));
clean_rows = all_rows(valid_idx, :);
fprintf('Valid results: %d / %d\n', sum(valid_idx), num_files);

% Build Table
ML_Table = array2table(clean_rows, 'VariableNames', col_names);

% Assign string labels for Condition
Condition = strings(height(ML_Table), 1);
Condition(ML_Table.Emax < 0.25) = "Failure";
Condition(ML_Table.Emax >= 0.25 & ML_Table.Emax < 0.6) = "Recovery";
Condition(ML_Table.Emax >= 0.6) = "Normal";
ML_Table.Condition = categorical(Condition);

% Save
writetable(ML_Table, master_csv);
save(master_mat, 'ML_Table');

% Save accepted file list
save(accepted_mat, 'accepted_files');

% Write exclusion log
if ~isempty(exclusion_rows)
    ExclusionTable = cell2table(vertcat(exclusion_rows{:}), ...
        'VariableNames', {'File', 'Reason', 'Detail'});
    writetable(ExclusionTable, exclusion_log);
    fprintf('\nExclusion log saved: %s (%d entries)\n', exclusion_log, height(ExclusionTable));
else
    fprintf('\nNo exclusions. All files passed QC.\n');
end

elapsed = toc(t_start);
fprintf('\nDone in %.1f seconds.\n', elapsed);
fprintf('Master LH CSV: %s (%d rows x %d features)\n', master_csv, height(ML_Table), width(ML_Table));
fprintf('Master LH MAT: %s\n', master_mat);

%% Quick Summary
fprintf('\n--- Class Distribution ---\n');
fprintf('  Failure  : %d\n', sum(ML_Table.Condition == "Failure"));
fprintf('  Recovery : %d\n', sum(ML_Table.Condition == "Recovery"));
fprintf('  Normal   : %d\n', sum(ML_Table.Condition == "Normal"));
