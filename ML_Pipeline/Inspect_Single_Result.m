%% ============================================================
%   INSPECT SINGLE RESULT
%   Loads one simulation .mat file and displays its features
%   and signals for verification.
% ============================================================

clc; clear; close all;

%% 1. Select File
% --- CHANGE THIS TO THE FILE YOU WANT TO INSPECT ---
SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\simulations_LH';
target_file = 'Result_LH_0001110.mat'; % Example file name

full_path = fullfile(SHARED_DRIVE_PATH, target_file);

if ~isfile(full_path)
    error('File not found: %s', full_path);
end

%% 2. Load Data
fprintf('Loading: %s\n', target_file);
data = load(full_path);

%% 3. Display Inputs & Features
fprintf('\n--- INPUT PARAMETERS ---\n');
disp(data.Inputs);

fprintf('\n--- EXTRACTED FEATURES ---\n');
f_names = fieldnames(data.Features);
for i = 1:numel(f_names)
    fprintf('  %-12s: %.4f\n', f_names{i}, data.Features.(f_names{i}));
end

%% 4. Plot Raw Signals
if isfield(data, 'Signals')
    figure('Name', ['Signals: ' target_file], 'Color', 'w', 'Position', [100 100 1000 600]);
    
    % Subplot 1: Pump Flow
    subplot(2,1,1);
    if ~isempty(data.Signals.Qpump)
        plot(data.Signals.Qpump(:,1), data.Signals.Qpump(:,2), 'b', 'LineWidth', 1.5);
        title('Raw Pump Flow (Qpump)');
        xlabel('Time (s)'); ylabel('Flow (ml/s)');
        grid on;
    else
        text(0.5, 0.5, 'Qpump signal is empty (Simulation Failed)', 'HorizontalAlignment', 'center');
    end
    
    % Subplot 2: Cuff Pressure (from P_all timeseries)
    subplot(2,1,2);
    if isa(data.Signals.P_all, 'timeseries')
        % Column 3 is Pcuff
        plot(data.Signals.P_all.Time, data.Signals.P_all.Data(:,3), 'r', 'LineWidth', 1.5);
        title('Cuff Pressure (Pcuff)');
        xlabel('Time (s)'); ylabel('Pressure (mmHg)');
        grid on;
    elseif isstruct(data.Signals.P_all) && isfield(data.Signals.P_all, 'Data')
        % Fallback for struct-style logging
        plot(data.Signals.P_all.Time, data.Signals.P_all.Data(:,3), 'r', 'LineWidth', 1.5);
        title('Cuff Pressure (Pcuff)');
        xlabel('Time (s)'); ylabel('Pressure (mmHg)');
        grid on;
    else
        text(0.5, 0.5, 'P_all signal is empty or unknown format', 'HorizontalAlignment', 'center');
    end
else
    fprintf('\n[Note] No raw signals found in this file.\n');
end
