%% ============================================================
%   COMPILE MASTER DATABASE
%   Merges individual simulation .mat files into one ML-ready
%   CSV and MAT file.
% ============================================================

clc; close all;

%% Setup Folders
% --- CHANGE THIS TO THE SAME SHARED DRIVE PATH ---
SHARED_DRIVE_PATH = ''; 

if isempty(SHARED_DRIVE_PATH)
    db_folder  = fullfile('Data', 'ML_Database');
else
    db_folder = SHARED_DRIVE_PATH;
end

sim_folder = fullfile(db_folder, 'simulations');
master_csv = fullfile(db_folder, 'ML_Master_Database.csv');
master_mat = fullfile(db_folder, 'ML_Master_Database.mat');

if ~exist(sim_folder, 'dir')
    error('No simulation folder found at %s', sim_folder);
end

%% Get List of Result Files
files = dir(fullfile(sim_folder, 'Result_*.mat'));
num_files = length(files);
fprintf('Found %d simulation result files.\n', num_files);

if num_files == 0
    error('No results found. Run Build_ML_Database.m first.');
end

%% Count Errors
err_files = dir(fullfile(sim_folder, 'ERROR_*.txt'));
fprintf('Found %d error files (failed simulations).\n', length(err_files));

%% Column Definitions (Must match Build_ML_Database.m)
col_names = {'Emax', 'RPM', 'Afterload', 'Preload', ...
             'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', ...
             'MAP', 'SBP', 'DBP'};

num_cols = length(col_names);

%% Preallocate and Compile
all_rows = NaN(num_files, num_cols);

fprintf('Compiling database...\n');
t_start = tic;

for i = 1:num_files
    filename = fullfile(files(i).folder, files(i).name);

    try
        data = load(filename, 'Inputs', 'Features');

        row = [ ...
            data.Inputs.Emax, ...
            data.Inputs.RPM, ...
            data.Inputs.AL, ...
            data.Inputs.PL, ...
            data.Features.FFT_H1, ...
            data.Features.FFT_H2, ...
            data.Features.PumpFlow, ...
            data.Features.dPumpFlow, ...
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
fprintf('Master CSV: %s (%d rows x %d features)\n', master_csv, height(ML_Table), width(ML_Table));
fprintf('Master MAT: %s\n', master_mat);

%% Quick Summary
fprintf('\n--- Class Distribution ---\n');
fprintf('  Failing  (0): %d samples\n', sum(ML_Table.Condition == 0));
fprintf('  Recovery (1): %d samples\n', sum(ML_Table.Condition == 1));
fprintf('  Normal   (2): %d samples\n', sum(ML_Table.Condition == 2));

fprintf('\n--- Feature Ranges ---\n');
for c = 5:num_cols % Skip input columns
    vals = clean_rows(:, c);
    fprintf('  %-12s  min=%8.3f  max=%8.3f  mean=%8.3f\n', ...
        col_names{c}, min(vals), max(vals), mean(vals));
end
