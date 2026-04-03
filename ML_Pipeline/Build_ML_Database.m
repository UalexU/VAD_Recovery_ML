%% ============================================================
%   BUILD ML DATABASE - Distributed 4D Sweep
%   Generates a comprehensive simulation database for ML training.
%   Designed for MULTI-COMPUTER execution.
% ============================================================
%
%   Sweep Axes (4D):
%     1. Emax (strength_factor) - 25% tolerance zones around 0.18, 0.3, 1.0
%     2. RPM  (pump_speed)      - 8k to 10k (100 steps)
%     3. Afterload (Rsp_Gain)   - 0.05 (5%) to 5.0 (500%)
%     4. Preload (Vusv_Gain)    - 0.1 (10%) to 1.9 (190%)
%
%   Final Features per simulation:
%     Inputs:  Emax, RPM, Afterload, Preload
%     Outputs: FFT_H1, FFT_H2, PumpFlow, dPumpFlow, MAP, SBP, DBP
%
%   How to use on multiple computers:
%     1. Sync this folder (via OneDrive/Dropbox/Git) to all PCs.
%     2. Run this script on all PCs simultaneously.
%     3. The script shuffles the workload and skips existing files.
%     4. Output is saved to 'Data/ML_Database/simulations/'.
%     5. When all sims are done, run 'Compile_Master_Database.m'.
%
% ============================================================

clc; close all;

%% Add helper function folder
addpath('..'); % For model and constants
addpath(genpath('../modules'));

%% Global model path
global BASENAME
BASENAME = 'modelv3/Interface/';

%% Load constants
HeartConstantsv3;

%% ============================================================
%              SWEEP AXIS DEFINITIONS (From Professor's Notes)
%
%   For the full 4D grid, we use COARSER steps to keep the total
%   simulation count manageable. The fine-step values from the notes
%   (e.g., 100 RPM steps) are meant for individual 1D sweeps.
%
%   To increase resolution on any axis, just change the step size.
%   Total sims = len(emax) * len(rpm) * len(afterload) * len(preload)
% ============================================================

% Emax: 30% tolerance zones around clinical operating points
%   Failing  (0.18): distance to Recovery = 0.12 -> 30% = 0.036 -> [0.144, 0.216]
%   Recovery (0.30): distance to Failing  = 0.12 -> 30% = 0.036; to Normal = 0.70 -> 30% = 0.21 -> [0.264, 0.51]
%   Normal   (1.00): distance to Recovery = 0.70 -> 30% = 0.21 -> [0.79, 1.21]
emax_sweep = [0.14:0.025:0.22, 0.26:0.025:0.52, 0.80:0.025:1.20];

% RPM: 8k to 10k (Notes: 100 steps -> 8:0.02:10 for 1D sweep)
% For 4D grid we use a smaller step size to keep total manageable
rpm_sweep = 8:0.2:10;                  % 11 steps

% Afterload: Rsp Gain Factor 0.05 (5%) to 5.0 (500%)
% Notes: step 0.025 for 1D sweep -> 200 steps
% For 4D grid we use a smaller step size
afterload_sweep = [0.05, 0.5:0.5:5.0]; % 11 steps

% Preload: Vusv Gain Factor 0.1 (10%) to 1.9 (190%)
preload_sweep = 0.1:0.2:1.9;           % 10 steps

%% ============================================================
%                  GENERATE JOB LIST
% ============================================================

jobs = struct('Emax', {}, 'RPM', {}, 'AL', {}, 'PL', {}, 'ID', {});

fprintf('=== ML Database Builder (Distributed) ===\n');
fprintf('Emax:      %d levels [%.2f to %.2f]\n', numel(emax_sweep), emax_sweep(1), emax_sweep(end));
fprintf('RPM:       %d levels [%.1f to %.1f]\n', numel(rpm_sweep), rpm_sweep(1), rpm_sweep(end));
fprintf('Afterload: %d levels [%.2f to %.2f] (Rsp Gain)\n', numel(afterload_sweep), afterload_sweep(1), afterload_sweep(end));
fprintf('Preload:   %d levels [%.1f to %.1f] (Vusv Gain)\n', numel(preload_sweep), preload_sweep(1), preload_sweep(end));

for e = emax_sweep
    for r = rpm_sweep
        for a = afterload_sweep
            for p = preload_sweep
                id = sprintf('Emax%.2f_RPM%.1f_AL%.2f_PL%.1f', e, r, a, p);
                new_job.Emax = e;
                new_job.RPM  = r;
                new_job.AL   = a;
                new_job.PL   = p;
                new_job.ID   = id;
                jobs(end+1) = new_job; %#ok<*SAGROW>
            end
        end
    end
end

total_jobs = numel(jobs);
fprintf('Total Simulations: %d\n', total_jobs);

% Shuffle for multi-computer collision avoidance
rng('shuffle');
jobs = jobs(randperm(total_jobs));
fprintf('Job list shuffled.\n');

%% ============================================================
%                  OUTPUT SETUP
% ============================================================

% --- CHANGE THIS TO YOUR SHARED DRIVE PATH ---
% Example: 'Z:\Lab_Thesis\Simulations' or '/Volumes/Shared/Sims'
% If you leave it empty '', it will use the local Data folder.

SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\simulations_30'; 

if isempty(SHARED_DRIVE_PATH)
    db_folder  = fullfile('Data', 'ML_Database');
else
    db_folder = SHARED_DRIVE_PATH;
end

% sim_folder = fullfile(db_folder, 'simulations');
sim_folder = SHARED_DRIVE_PATH;
if ~exist(sim_folder, 'dir'), mkdir(sim_folder); end

%% Fixed parameters
pump_on = 1;
threshold = 0.25;
Vuev_Gain_Factor = 1;

%% ============================================================
%                    MAIN SIMULATION LOOP
% ============================================================

fprintf('\nStarting Distributed Simulation...\n');
fprintf('Output: %s\n\n', sim_folder);

t_start = tic;
completed_session = 0;
skipped = 0;

for i = 1:total_jobs
    job = jobs(i);

    % --- 1. Check if Already Done ---
    filename = fullfile(sim_folder, ['Result_' job.ID '.mat']);
    err_file = fullfile(sim_folder, ['ERROR_' job.ID '.txt']);

    if isfile(filename) || isfile(err_file)
        skipped = skipped + 1;
        continue;
    end

    % --- 2. Set Simulation Parameters ---
    strength_factor = job.Emax;
    pump_speed      = job.RPM;
    Rsp_Gain_Factor = job.AL;
    Rep_Gain_Factor = job.AL;
    Vusv_Gain_Factor = job.PL;  % Preload via Vusv gain (used instead of Vt0)

    fprintf('[%d/%d] Running: %s ... ', i, total_jobs, job.ID);

    % --- 3. Run Simulation ---
    try
        sim_tic = tic;
        sim('modelv3_1');
        sim_time = toc(sim_tic);
    catch ME
        fprintf('FAILED (%s)\n', ME.message);
        fid = fopen(err_file, 'w');
        fprintf(fid, '%s', ME.message);
        fclose(fid);
        continue;
    end

    % --- 4. Extract Final Features ---
    try
        simData = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink);
        oscData = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, ...
                                       Qpump, dQpump, simData.HR);

        result = struct();
        result.ID     = job.ID;
        result.Inputs = job;

        % Final Features
        result.Features.FFT_H1    = oscData.H1;       % Cuff pressure 1st harmonic
        result.Features.FFT_H2    = oscData.H2;       % Cuff pressure 2nd harmonic
        result.Features.PumpFlow  = oscData.Qpump;    % Flow pulsatility (peak-to-peak)
        result.Features.dPumpFlow = oscData.dQpump;   % Flow derivative pulsatility (peak-to-peak)
        result.Features.dQ_H1     = oscData.dQ_H1;   % dQ/dt 1st harmonic (preload-sensitive)
        result.Features.dQ_H2     = oscData.dQ_H2;   % dQ/dt 2nd harmonic (waveform shape)
        result.Features.MAP       = oscData.MAP;      % Mean Arterial Pressure (Cuff)
        result.Features.SBP       = oscData.SBP;      % Systolic Pressure (Cuff)
        result.Features.DBP       = oscData.DBP;      % Diastolic Pressure (Cuff)

        % Raw signals for post-processing
        result.Signals.P     = P;     % Primary pressure log
        result.Signals.P_all = P_all; % Full pressure array (contains Pcuff)
        result.Signals.Qpump = Qpump; % Raw pump flow
        result.Signals.Psa   = Psa_log; % Systemic arterial pressure log (extra redundancy)

        % --- 5. Save ---
        save(filename, '-struct', 'result');

        fprintf('Done (%.1fs)\n', sim_time);
        completed_session = completed_session + 1;

    catch ME
        fprintf('Extract error: %s\n', ME.message);
    end

    % Progress report every 10 completions
    if mod(completed_session, 10) == 0 && completed_session > 0
        elapsed = toc(t_start);
        rate = completed_session / elapsed;
        remaining = (total_jobs - skipped - completed_session) / rate;
        fprintf('  >> %.1f sims/min | ETA: %.0f min\n', rate * 60, remaining / 60);
    end

end

fprintf('\n=== Session Complete ===\n');
fprintf('Completed this session: %d\n', completed_session);
fprintf('Skipped (already done): %d\n', skipped);
fprintf('Run Compile_Master_Database.m to merge all results.\n');
