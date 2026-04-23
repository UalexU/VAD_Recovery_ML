%% ============================================================
%   BUILD ML DATABASE - Grid OR uniform Monte Carlo on a 4D box
%   Same outputs as Build_ML_Database.m; job IDs are MC_0000001 ... or grid-style.
%   Designed for MULTI-COMPUTER execution (skip-if-exists).
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
%              GRID vs UNIFORM MONTE CARLO
%
%   GRID:  Full factorial over discrete levels (deterministic).
%
%   UNIFORM MC:  N independent Uniform draws on a 4D box
%          [emax_lo,emax_hi] x [rpm_lo,rpm_hi] x [al_lo,al_hi] x [pl_lo,pl_hi].
%          Same resume/skip logic as the grid builder.
%
%   Caveat: A single box fills the *rectangle* between bounds; it does not
%   reproduce the union of three disjoint Emax bands unless you use a
%   mixture (sample zone, then uniform inside) or rejection sampling.
%
%   IDs: MC_0000001 ... MC_N avoids float collisions in filenames.
%   Optional: Latin Hypercube (lhsdesign) for space-filling with fixed N.
% ============================================================

USE_MONTE_CARLO = true;   % false = full factorial grid (emax_sweep, etc.)
N_MC = 30000;              % Monte Carlo sample count (if USE_MONTE_CARLO)

rng_seed = 42;            % set for reproducibility; or use rng('shuffle') below
rng(rng_seed);

% --- Grid axes (used when USE_MONTE_CARLO = false)
emax_sweep = [0.14:0.025:0.22, 0.26:0.025:0.52, 0.80:0.025:1.20];
rpm_sweep       = 8:0.2:10;
afterload_sweep = [0.05, 0.5:0.5:5.0];
preload_sweep   = 0.1:0.2:1.9;

% --- Monte Carlo bounds (edit to match your study; default = box covering grid ranges)
emax_lo = 0.14;   emax_hi = 1.20;
rpm_lo  = 8;      rpm_hi  = 10;
al_lo   = 0.05;   al_hi   = 5.0;
pl_lo   = 0.1;    pl_hi   = 1.9;

%% ============================================================
%                  GENERATE JOB LIST
% ============================================================

jobs = struct('Emax', {}, 'RPM', {}, 'AL', {}, 'PL', {}, 'ID', {});

fprintf('=== ML Database Builder (Monte Carlo / Distributed) ===\n');

if USE_MONTE_CARLO 
    fprintf('Mode: UNIFORM DISTRIBUTION MONTE CARLO (N = %d)\n', N_MC);
    fprintf('  Emax [%.2f, %.2f], RPM [%.1f, %.1f], AL [%.2f, %.2f], PL [%.1f, %.1f]\n', ...
        emax_lo, emax_hi, rpm_lo, rpm_hi, al_lo, al_hi, pl_lo, pl_hi);
    u = rand(N_MC, 4); % random numbers between 0 and 1, 4 columns for emax, rpm, al, pl
    for k = 1:N_MC
        new_job.Emax = emax_lo + u(k,1) * (emax_hi - emax_lo);
        new_job.RPM  = rpm_lo  + u(k,2) * (rpm_hi  - rpm_lo);
        new_job.AL   = al_lo   + u(k,3) * (al_hi   - al_lo);
        new_job.PL   = pl_lo   + u(k,4) * (pl_hi   - pl_lo);
        new_job.ID   = sprintf('MC_%07d', k); % Max 7 index digits
        jobs(end+1) = new_job; 
    end
else % normal grid mode without monte carlo sampling
    fprintf('Mode: FULL FACTORIAL GRID\n');
    fprintf('Emax:      %d levels [%.2f to %.2f]\n', numel(emax_sweep), emax_sweep(1), emax_sweep(end));
    fprintf('RPM:       %d levels [%.1f to %.1f]\n', numel(rpm_sweep), rpm_sweep(1), rpm_sweep(end));
    fprintf('Afterload: %d levels [%.2f to %.2f] (Rsp Gain)\n', numel(afterload_sweep), afterload_sweep(1), afterload_sweep(end));
    fprintf('Preload:   %d levels [%.1f to %.1f] (Vusv Gain)\n', numel(preload_sweep), preload_sweep(1), preload_sweep(end));
    for e = emax_sweep
        for r = rpm_sweep
            for alv = afterload_sweep
                for p = preload_sweep
                    id = sprintf('Emax%.2f_RPM%.1f_AL%.2f_PL%.1f', e, r, alv, p);
                    new_job.Emax = e;
                    new_job.RPM  = r;
                    new_job.AL   = alv;
                    new_job.PL   = p;
                    new_job.ID   = id;
                    jobs(end+1) = new_job; %#ok<*SAGROW>
                end
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

SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\MC_Simulation\MC_Simulations_Part2'; 

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
    Vusv_Gain_Factor = job.PL;

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
        result.Features.FFT_H1    = oscData.H1;
        result.Features.FFT_H2    = oscData.H2;
        result.Features.PumpFlow  = oscData.Qpump;
        result.Features.dPumpFlow = oscData.dQpump;
        result.Features.dQ_H1     = oscData.dQ_H1;
        result.Features.dQ_H2     = oscData.dQ_H2;
        result.Features.MAP       = oscData.MAP;
        result.Features.SBP       = oscData.SBP;
        result.Features.DBP       = oscData.DBP;

        % Raw signals for post-processing
        result.Signals.P     = P;
        result.Signals.P_all = P_all;
        result.Signals.Qpump = Qpump;
        result.Signals.Psa   = Psa_log;

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
