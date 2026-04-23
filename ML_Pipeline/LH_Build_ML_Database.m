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
%     STEP 1 (one PC only): Set GENERATE_JOBS = true, run once.
%            This saves LH_jobs_NNNNN.mat to the shared drive.
%     STEP 2 (all PCs):    Set GENERATE_JOBS = false, run simultaneously.
%            Each PC loads the same job list, shuffles independently,
%            and skips files already saved by other PCs.
%     STEP 3: Run Compile_Master_Database.m when all sims are done.
%
%   NOTE: Do NOT split N_LH across computers (e.g. 15000 each).
%         LHS is a single coordinated design — splitting produces two
%         separate 15k designs that when merged miss bins and double-
%         cover others, losing the stratification guarantee.
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

% --- USER SETTINGS ---
N_LH          = 30000; % Total samples for the FULL design (all PCs combined)
rng_seed      = 42;    % Fixed seed — must be identical on every PC
maximin_iters = 50;    % Optimisation iterations (higher = better coverage, slower)

% Set true on ONE PC first to generate and save the job list.
% Then set false and run on all PCs to execute simulations.
GENERATE_JOBS = true;

% 4D bounding box [lo, hi]
emax_lo = 0.14;   emax_hi = 1.20;
rpm_lo  = 8;       rpm_hi  = 10;
al_lo   = 0.05;    al_hi   = 5.0;
pl_lo   = 0.1;     pl_hi   = 1.9;

%% ============================================================
%              SHARED DRIVE PATH
% ============================================================

SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\simulations_LH';

if isempty(SHARED_DRIVE_PATH)
    sim_folder = fullfile('..', 'Data', 'ML_Database_LH', 'simulations');
else
    sim_folder = SHARED_DRIVE_PATH;
end

if ~exist(sim_folder, 'dir'), mkdir(sim_folder); end

% Job list file lives on the shared drive so all PCs load the same design
jobs_file = fullfile(sim_folder, sprintf('LH_jobs_%d.mat', N_LH));

%% ============================================================
%              GENERATE OR LOAD JOB LIST
% ============================================================

fprintf('=== ML Database Builder (Latin Hypercube / Distributed) ===\n');

if GENERATE_JOBS
    fprintf('Mode: GENERATE — creating %d-point maximin LHS design (seed=%d)...\n', N_LH, rng_seed);

    rng(rng_seed);
    tic;
    U = lhsdesign(N_LH, 4, 'Criterion', 'maximin', 'Iterations', maximin_iters);
    fprintf('LHS design generated in %.1fs.\n', toc);

    % Scale [0,1]^4 to physical bounds
    Emax_samples = emax_lo + U(:,1) * (emax_hi - emax_lo);
    RPM_samples  = rpm_lo  + U(:,2) * (rpm_hi  - rpm_lo);
    AL_samples   = al_lo   + U(:,3) * (al_hi   - al_lo);
    PL_samples   = pl_lo   + U(:,4) * (pl_hi   - pl_lo);

    jobs = struct('Emax', {}, 'RPM', {}, 'AL', {}, 'PL', {}, 'ID', {});
    for k = 1:N_LH
        new_job.Emax = Emax_samples(k);
        new_job.RPM  = RPM_samples(k);
        new_job.AL   = AL_samples(k);
        new_job.PL   = PL_samples(k);
        new_job.ID   = sprintf('LH_%07d', k);
        jobs(end+1)  = new_job; %#ok<SAGROW>
    end

    save(jobs_file, 'jobs', 'N_LH', 'rng_seed', 'emax_lo', 'emax_hi', ...
         'rpm_lo', 'rpm_hi', 'al_lo', 'al_hi', 'pl_lo', 'pl_hi');
    fprintf('Job list saved to: %s\n', jobs_file);
    fprintf('Now set GENERATE_JOBS = false and run on all PCs.\n');
    return; % Stop here — do NOT run simulations in generation mode

else
    if ~isfile(jobs_file)
        error('Job list not found at %s.\nRun with GENERATE_JOBS = true first (on one PC).', jobs_file);
    end
    fprintf('Mode: SIMULATE — loading job list from shared drive...\n');
    loaded = load(jobs_file, 'jobs');
    jobs = loaded.jobs;
    fprintf('Loaded %d jobs (seed=%d).\n', numel(jobs), rng_seed);
end

total_jobs = numel(jobs);
fprintf('Total Simulations: %d\n', total_jobs);

% Shuffle for multi-computer collision avoidance
rng('shuffle');
jobs = jobs(randperm(total_jobs));
fprintf('Job list shuffled for distributed execution.\n');

%% Fixed parameters
pump_on = 1;
threshold = 0.25;
Vuev_Gain_Factor = 1;

% --- Drop suction-like runs from the ML set (no Result_*.mat; see EXCLUDED_SUCTION_*.txt) ---
EXCLUDE_SUCTION              = true;
SUCTION_PLV_MIN_THRESHOLD_MMHG = 0;    % steady-state min Plv below this => exclude (mmHg); try 5 for stricter
SUCTION_STEADY_STATE_FRAC    = 0.5;  % last 50 percent of Plv_log (by time) for min Plv

%% ============================================================
%                    MAIN SIMULATION LOOP
% ============================================================

fprintf('\nStarting Parallel Distributed Simulation...\n');
fprintf('Output: %s\n\n', sim_folder);

% Make BASENAME local for parfor workers
local_basename = BASENAME;

t_start = tic;

parfor i = 1:total_jobs
    job = jobs(i);

    % --- 0. Worker Environment Setup ---
    global BASENAME
    BASENAME = local_basename;
    HeartConstantsv3;

    % --- 1. Check if Already Done ---
    filename = fullfile(sim_folder, ['Result_' job.ID '.mat']);
    err_file = fullfile(sim_folder, ['ERROR_' job.ID '.txt']);
    suction_excl_file = fullfile(sim_folder, ['EXCLUDED_SUCTION_' job.ID '.txt']);

    if isfile(filename) || isfile(err_file) || isfile(suction_excl_file)
        continue;
    end

    % --- 2. Set Simulation Parameters ---
    strength_factor  = job.Emax;
    pump_speed       = job.RPM;
    Rsp_Gain_Factor  = job.AL;
    Rep_Gain_Factor  = job.AL;
    Vusv_Gain_Factor = job.PL;

    % --- 3. Run Simulation ---
    try
        sim_tic = tic;
        sim('modelv3_1', 'SrcWorkspace', 'current');
        sim_time = toc(sim_tic);
    catch ME
        fprintf('FAILED: %s (%s)\n', job.ID, ME.message);
        fid = fopen(err_file, 'w');
        if fid ~= -1
            fprintf(fid, '%s', ME.message);
            fclose(fid);
        end
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

        % Raw signals
        result.Signals.P     = P;
        result.Signals.P_all = P_all;
        result.Signals.Qpump = Qpump;
        result.Signals.Psa   = Psa_log;

        % --- 5. Suction filter ---
        % Using local variables to avoid parfor transparency issues
        local_exclude_suction = EXCLUDE_SUCTION;
        local_suction_threshold = SUCTION_PLV_MIN_THRESHOLD_MMHG;
        local_suction_frac = SUCTION_STEADY_STATE_FRAC;

        if local_exclude_suction
            [in_suction, suctInfo] = detectSuctionFromSim(Plv_log, ...
                'PlvMinThreshold', local_suction_threshold, ...
                'SteadyStateFrac', local_suction_frac);
            if in_suction
                fid = fopen(suction_excl_file, 'w');
                if fid ~= -1
                    fprintf(fid, '%s\n', suctInfo.reason);
                    fclose(fid);
                end
                fprintf('EXCLUDED suction: %s (%.1fs)\n', job.ID, sim_time);
                continue;
            end
        end

        % --- 6. Save ---
        saveResultFile(filename, result);

        fprintf('Done: %s (%.1fs)\n', job.ID, sim_time);

    catch ME
        fprintf('Extract error on %s: %s\n', job.ID, ME.message);
    end

end

fprintf('\n=== Session Complete ===\n');
fprintf('Completed this session: %d\n', completed_session);
fprintf('Excluded (suction heuristic): %d\n', excluded_suction);
fprintf('Skipped (already done): %d\n', skipped);
fprintf('Run Compile_LH_Database.m to merge Result_LH_*.mat into the master table.\n');
