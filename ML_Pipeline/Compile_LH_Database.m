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

%% Column Definitions (Must match LH_Build_ML_Database.m)
col_names = {'Emax', 'RPM', 'Afterload', 'Preload', ...
             'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', ...
             'dQ_H1', 'dQ_H2', ...
             'MAP', 'SBP', 'DBP'};

num_cols = length(col_names);

%% Preallocate and Compile
all_rows = NaN(num_files, num_cols);

fprintf('Compiling LH database...\n');
t_start = tic;

for i = 1:num_files
    filename = fullfile(files(i).folder, files(i).name);

    try
        data = load(filename); % Load full struct for repair check

        % --- AUTO-REPAIR: Missing dQ_H1/dQ_H2 ---
        if ~isfield(data.Features, 'dQ_H1') || ~isfield(data.Features, 'dQ_H2')
            if isfield(data, 'Signals') && isfield(data.Signals, 'Qpump')
                % Extract Qpump
                if isa(data.Signals.Qpump, 'timeseries')
                    Q_raw = data.Signals.Qpump.Data;
                    time_q = data.Signals.Qpump.Time;
                else
                    Q_raw = data.Signals.Qpump(:, 2);
                    time_q = data.Signals.Qpump(:, 1);
                end
                Ts_q = time_q(2) - time_q(1);
                
                % Calculate dQ/dt and filter (Matches extractOscillometric.m)
                dQ_numeric = [0; diff(Q_raw)] ./ Ts_q;
                fs_q = 1/Ts_q;
                [b, a] = butter(3, 20/(fs_q/2), 'low');
                dQ_filtered = filtfilt(b, a, dQ_numeric);
                
                % Trim to last 20% for harmonics
                start_idx = round(length(dQ_filtered) * 0.8);
                dQ_trim = dQ_filtered(start_idx:end);
                time_dQ = (0:length(dQ_trim)-1)' * Ts_q;
                
                % Get Harmonics
                [h1, h2] = getFFT(dQ_trim, time_dQ, false);
                
                % Update data structure
                data.Features.dQ_H1 = h1;
                data.Features.dQ_H2 = h2;
                
                % Save back to file (Selective save to avoid corrupting other fields)
                save(filename, '-struct', 'data');
                fprintf('  [Repaired] %s: Added dQ harmonics.\n', files(i).name);
            else
                % If no signals, fill with NaN to allow compile to continue
                data.Features.dQ_H1 = NaN;
                data.Features.dQ_H2 = NaN;
            end
        end

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

        all_rows(i, :) = row;

    catch
        fprintf('  Warning: Corrupt file %s\n', files(i).name);
    end
end

%% Clean and Save
valid_idx = ~isnan(all_rows(:, 1));
clean_rows = all_rows(valid_idx, :);
fprintf('Valid results: %d / %d\n', sum(valid_idx), num_files);

% Build Table
ML_Table = array2table(clean_rows, 'VariableNames', col_names);

% Add Classification Label
% 0 = Failing (Emax < 0.25)
% 1 = Recovery (0.25 <= Emax < 0.6)
% 2 = Normal (Emax >= 0.6)
Condition = zeros(height(ML_Table), 1);
Condition(ML_Table.Emax >= 0.25 & ML_Table.Emax < 0.6) = 1;
Condition(ML_Table.Emax >= 0.6) = 2;
ML_Table.Condition = Condition;

% Save
writetable(ML_Table, master_csv);
save(master_mat, 'ML_Table');

elapsed = toc(t_start);
fprintf('\nDone in %.1f seconds.\n', elapsed);
fprintf('Master LH CSV: %s (%d rows x %d features)\n', master_csv, height(ML_Table), width(ML_Table));
fprintf('Master LH MAT: %s\n', master_mat);

%% Quick Summary
fprintf('\n--- Class Distribution ---\n');
fprintf('  Failing  (0): %d samples\n', sum(ML_Table.Condition == 0));
fprintf('  Recovery (1): %d samples\n', sum(ML_Table.Condition == 1));
fprintf('  Normal   (2): %d samples\n', sum(ML_Table.Condition == 2));
