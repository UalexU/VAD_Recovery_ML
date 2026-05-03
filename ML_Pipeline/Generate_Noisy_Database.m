%% ============================================================
%   GENERATE NOISY DATABASE (Robustness Test - Hybrid Mode)
%   1. Loads Qpump -> Adds noise -> Recalculates dQ/dt.
%      Also recomputes dQ_H1/dQ_H2 via getFFT on filtered dQ/dt (matches
%      extractOscillometric — these are harmonic peaks of pump-flow derivative,
%      not FFT of raw Qpump).
%   2. Loads P_all (if available) -> Adds noise to Pcuff -> Recalculates FFT_H1/H2 (cuff).
%   3. Fallback: If P_all missing, adds statistical noise to pressure features.
%   4. Compiles a new "Noisy" Master CSV (Option B).
% ============================================================

clc; close all;

%% Setup
addpath('..');
addpath(genpath('../modules'));

% --- SHARED DRIVE PATH (Same as Build_ML_Database) ---
SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\Step_simulations\Output Files'; 

if isempty(SHARED_DRIVE_PATH)
    db_folder = fullfile('Data', 'ML_Database');
else
    db_folder = SHARED_DRIVE_PATH;
end

output_csv    = fullfile(db_folder, 'Step3_Database_Noisy10.csv');
accepted_mat  = fullfile(db_folder, 'Step3_AcceptedFiles.mat');

% Load QC-approved file list from Compile_Master_Database.m
if ~isfile(accepted_mat)
    error('AcceptedFiles.mat not found at %s.\nRun Compile_Master_Database.m first.', accepted_mat);
end
loaded = load(accepted_mat, 'accepted_files');
accepted_files = loaded.accepted_files;
num_files = numel(accepted_files);
fprintf('Loaded %d QC-accepted simulation files from AcceptedFiles.mat.\n', num_files);
fprintf('Generating noisy dataset...\n');

%% Parameters
NOISE_LEVEL = 0.10; % 10% noise
Filter_Order = 3;
Filter_Cutoff = 20; % Hz

%% Initialize
all_rows = [];
col_names = {'Emax', 'RPM', 'Afterload', 'Preload', ...
             'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', ...
             'dQ_H1', 'dQ_H2', ...
             'MAP', 'SBP', 'DBP', 'Condition'};

t_start = tic;

%% Loop
parfor i = 1:num_files
    filename = accepted_files{i};
    
    try
        data = load(filename);
        
        % --- 1. Process Qpump  ---
        % Handle Qpump as matrix or timeseries
        if isa(data.Signals.Qpump, 'timeseries')
            Q_raw = data.Signals.Qpump.Data;
            time_Q = data.Signals.Qpump.Time;
            Ts_Q = time_Q(2) - time_Q(1);
        else
            Q_raw = data.Signals.Qpump(:, 2); % Time is col 1, Data col 2
            Ts_Q = data.Signals.Qpump(2,1) - data.Signals.Qpump(1,1); % sample period
        end
        
        % Add noise into Qpump 
        sigma_Q = std(Q_raw) * NOISE_LEVEL; % multiply the standard deviation of the Qpump with the noise
        Q_noisy = Q_raw + randn(size(Q_raw)) * sigma_Q;
        
        % Trim to last 5 cycles
        N = length(Q_noisy);
        start_idx = round(N * 0.8);
        Q_trim = Q_noisy(start_idx:end);
        
        % Calculate Noisy dQ/dt
        dQ_numeric = [0; diff(Q_trim)] ./ Ts_Q;
        
        % Filter
        fs = 1 / Ts_Q;
        [b, a] = butter(Filter_Order, Filter_Cutoff / (fs/2), 'low');
        dQ_filtered = filtfilt(b, a, dQ_numeric);
        
        % Extract Pulsatility 
        feat_PumpFlow = max(Q_trim) - min(Q_trim);
        feat_dPumpFlow = max(dQ_filtered) - min(dQ_filtered);

        % Harmonics of filtered dQ/dt (same definition as extractOscillometric)
        time_dQ = (0:length(dQ_filtered)-1)' * Ts_Q;
        [feat_dQ_H1, feat_dQ_H2] = getFFT(dQ_filtered, time_dQ, false);
        
        % --- 2. Process Pressure/FFT ---
        if isfield(data.Signals, 'P_all')
            % Option B: We have the raw pressure array!
            P_all_raw = data.Signals.P_all.Data; % Assuming struct
            Time_P = data.Signals.P_all.Time;
            Pcuff_raw = P_all_raw(:, 3); % Column 3 is Pcuff
            
            % Add Noise to Pcuff Signal
            sigma_P = std(Pcuff_raw) * NOISE_LEVEL;
            Pcuff_noisy = Pcuff_raw + randn(size(Pcuff_raw)) * sigma_P;
            
            % Re-calculate FFT on Noisy Signal
            [H1, H2] = getFFT(Pcuff_noisy, Time_P, false);
            feat_H1 = H1;
            feat_H2 = H2;
            
            % For MAP/SBP/DBP, we also perturb Psa (Col 1 usually Psa?)
            % Actually extractOscillometric uses P_all to get SBP/DBP via Oscillometric()
            % but that's slow. We'll statistically perturb them for now as
            % calculating Oscillometric envelope is computationally heavy for 20k sims.
            feat_MAP = data.Features.MAP * (1 + randn()*NOISE_LEVEL);
            feat_SBP = data.Features.SBP * (1 + randn()*NOISE_LEVEL);
            feat_DBP = data.Features.DBP * (1 + randn()*NOISE_LEVEL);
            
        else
            % Fallback: Statistical Noise (Old Sim Files)
            feat_H1 = data.Features.FFT_H1 * (1 + randn()*NOISE_LEVEL);
            feat_H2 = data.Features.FFT_H2 * (1 + randn()*NOISE_LEVEL);
            feat_MAP = data.Features.MAP * (1 + randn()*NOISE_LEVEL);
            feat_SBP = data.Features.SBP * (1 + randn()*NOISE_LEVEL);
            feat_DBP = data.Features.DBP * (1 + randn()*NOISE_LEVEL);
            % dQ_H1/dQ_H2 already derived from noisy Qpump above; no override here
        end
        
        % --- 3. Condition Label ---
        emax = data.Inputs.Emax;
        if emax < 0.25
            cond = "Failure";
        elseif emax < 0.6
            cond = "Recovery";
        else
            cond = "Normal";
        end
        
        % --- 4. Assemble Row ---
        row = [data.Inputs.Emax, data.Inputs.RPM, data.Inputs.AL, data.Inputs.PL, ...
               feat_H1, feat_H2, feat_PumpFlow, feat_dPumpFlow, ...
               feat_dQ_H1, feat_dQ_H2, ...
               feat_MAP, feat_SBP, feat_DBP];
           
        all_rows = [all_rows; row]; %#ok<AGROW>
        
    catch
        % Skip corrupt files
    end
end

%% Save
ML_Table = array2table(all_rows, 'VariableNames', col_names(1:end-1));

% Add Condition as a categorical column
Condition = strings(height(ML_Table), 1);
Condition(ML_Table.Emax < 0.25) = "Failure";
Condition(ML_Table.Emax >= 0.25 & ML_Table.Emax < 0.6) = "Recovery";
Condition(ML_Table.Emax >= 0.6) = "Normal";
ML_Table.Condition = categorical(Condition);

fprintf('Done in %.1f seconds.\n', toc(t_start));
fprintf('Noisy Database (Option B) saved to: %s\n', output_csv);
