%% ============================================================
%   BUILD ML DATABASE - Latin Hypercube Sampling (LHS)
%   Space-filling 4D design using MATLAB's lhsdesign (maximin).
%   Same outputs / resume logic as Build_ML_Database.m.
% ============================================================
%
%   Why LHS over Uniform Monte Carlo?
%     - MC draws N i.i.d. points; some regions get clustered, others empty.
%     - LHS guarantees each marginal (Emax, RPM, AL, PL) is perfectly
%       stratified into N equal-probability bins.
%     - The 'maximin' criterion additionally maximises the minimum
%       inter-point distance in the FULL 4D space, giving the best
%       space-filling for a fixed sample budget.
%
%   Why lhsdesign(maximin) instead of LHSMDU?
%     - At 4 dimensions, maximin LHS is near-optimal; LHSMDU's
%       multi-dimensional uniformity metric adds marginal benefit
%       only above ~10 dimensions.
%     - lhsdesign is built into MATLAB's Statistics Toolbox (no
%       external Python bridge or File Exchange download).
%
%   Sweep Axes (4D):
%     1. Emax (strength_factor) - [0.14, 1.20]
%     2. RPM  (pump_speed)      - [8, 10]
%     3. Afterload (Rsp_Gain)   - [0.05, 5.0]
%     4. Preload (Vusv_Gain)    - [0.1, 1.9]
%
%   Final Features per simulation:
%     Inputs:  Emax, RPM, Afterload, Preload
%     Outputs: FFT_H1, FFT_H2, PumpFlow, dPumpFlow, MAP, SBP, DBP
%
%   How to use on multiple computers:
%     1. Generate the design ONCE on one PC (or use the same rng_seed).
%     2. Sync this folder to all PCs.
%     3. Run this script on all PCs simultaneously.
%     4. The script shuffles and skips existing files.
%     5. When done, run Compile_Master_Database.m.
%
% ============================================================

clc; close all;

%% Add helper function folder
addpath('..');
addpath(genpath('../modules'));

%% Global model path
global BASENAME
BASENAME = 'modelv3/Interface/';

%% Load constants
HeartConstantsv3;

%% ============================================================
%              LATIN HYPERCUBE CONFIGURATION
% ============================================================

N_LH = 5000;       % Total number of samples (tune to your compute budget)
rng_seed = 42;      % Fixed seed so every PC generates the SAME design
maximin_iters = 50; % Optimisation iterations for the maximin criterion

% 4D bounding box [lo, hi] for each axis
emax_lo = 0.14;   emax_hi = 1.20;
rpm_lo  = 8;       rpm_hi  = 10;
al_lo   = 0.05;    al_hi   = 5.0;
pl_lo   = 0.1;     pl_hi   = 1.9;

%% ============================================================
%              GENERATE LHS DESIGN
% ============================================================

fprintf('=== ML Database Builder (Latin Hypercube / Distributed) ===\n');
fprintf('Samples: %d | Maximin iterations: %d | Seed: %d\n', N_LH, maximin_iters, rng_seed);
fprintf('  Emax [%.3f, %.3f], RPM [%.1f, %.1f], AL [%.2f, %.2f], PL [%.1f, %.1f]\n', ...
    emax_lo, emax_hi, rpm_lo, rpm_hi, al_lo, al_hi, pl_lo, pl_hi);

rng(rng_seed);
fprintf('Generating maximin LHS design (%d x 4)... ', N_LH);
tic;
U = lhsdesign(N_LH, 4, 'Criterion', 'maximin', 'Iterations', maximin_iters);
fprintf('Done (%.1fs)\n', toc);

% Scale from [0,1]^4 to physical bounds
Emax_samples = emax_lo + U(:,1) * (emax_hi - emax_lo);
RPM_samples  = rpm_lo  + U(:,2) * (rpm_hi  - rpm_lo);
AL_samples   = al_lo   + U(:,3) * (al_hi   - al_lo);
PL_samples   = pl_lo   + U(:,4) * (pl_hi   - pl_lo);

%% ============================================================
%              BUILD JOB LIST
% ============================================================

jobs = struct('Emax', {}, 'RPM', {}, 'AL', {}, 'PL', {}, 'ID', {});

for k = 1:N_LH
    new_job.Emax = Emax_samples(k);
    new_job.RPM  = RPM_samples(k);
    new_job.AL   = AL_samples(k);
    new_job.PL   = PL_samples(k);
    new_job.ID   = sprintf('LH_%07d', k);
    jobs(end+1) = new_job; %#ok<SAGROW>
end

total_jobs = numel(jobs);
fprintf('Total Simulations: %d\n', total_jobs);

% Shuffle for multi-computer collision avoidance
rng('shuffle');
jobs = jobs(randperm(total_jobs));
fprintf('Job list shuffled for distributed execution.\n');

%% ============================================================
%                  OUTPUT SETUP
% ============================================================

SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\simulations_LH';

if isempty(SHARED_DRIVE_PATH)
    sim_folder = fullfile('..', 'Data', 'ML_Database_LH', 'simulations');
else
    sim_folder = SHARED_DRIVE_PATH;
end

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
    strength_factor  = job.Emax;
    pump_speed       = job.RPM;
    Rsp_Gain_Factor  = job.AL;
    Rep_Gain_Factor  = job.AL;
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
