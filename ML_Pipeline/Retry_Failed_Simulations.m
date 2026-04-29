%% ============================================================
%   RETRY & CLEANUP FAILED SIMULATIONS
%   Finds missing jobs from Build_ML_Database.m and retries them ONCE.
%   If they fail again, it marks them as permanently FAILED (NaN results).
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
%                  OUTPUT SETUP
% ============================================================

% Use the same path as Build_ML_Database.m
SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data\simulations_30'; 

if isempty(SHARED_DRIVE_PATH)
    db_folder  = fullfile('Data', 'ML_Database');
else
    db_folder = SHARED_DRIVE_PATH;
end

sim_folder = db_folder; 
if ~exist(sim_folder, 'dir')
    error('Simulation folder not found at: %s', sim_folder);
end

%% ============================================================
%                  REGENERATE JOB LIST
% ============================================================
% We must regenerate the exact same list to know what's missing.
emax_sweep = [0.14:0.025:0.22, 0.26:0.025:0.52, 0.80:0.025:1.20];
rpm_sweep       = 8:0.2:10;
afterload_sweep = [0.05, 0.5:0.5:5.0];
preload_sweep   = 0.1:0.2:1.9;

jobs = struct('Emax', {}, 'RPM', {}, 'AL', {}, 'PL', {}, 'ID', {});

fprintf('Regenerating full job list...\n');
for e = emax_sweep
    for r = rpm_sweep
        for a = afterload_sweep
            for p = preload_sweep
                id = sprintf('Emax%.2f_RPM%.1f_AL%.2f_PL%.1f', e, r, a, p);
                new_job.Emax = e; new_job.RPM = r; new_job.AL = a; new_job.PL = p; new_job.ID = id;
                jobs(end+1) = new_job; %#ok<*SAGROW>
            end
        end
    end
end

total_jobs = numel(jobs);
fprintf('Total jobs in grid: %d\n', total_jobs);

%% ============================================================
%                  FIND MISSING JOBS
% ============================================================

missing_indices = [];

fprintf('Scanning for missing files...\n');
for i = 1:total_jobs
    filename = fullfile(sim_folder, ['Result_' jobs(i).ID '.mat']);
    if ~isfile(filename)
        missing_indices(end+1) = i;
    end
end

num_missing = numel(missing_indices);
fprintf('Found %d missing/failed simulations.\n', num_missing);

if num_missing == 0
    fprintf('All done! No retries needed.\n');
    return;
end

%% ============================================================
%                  RETRY LOOP (Linear)
% ============================================================

fixed_params.pump_on = 1;
threshold = 0.25;
Vuev_Gain_Factor = 1;

fprintf('\nStarting Retry Session (Linear)...\n');

for k = 1:num_missing
    idx = missing_indices(k);
    job = jobs(idx);
    filename = fullfile(sim_folder, ['Result_' job.ID '.mat']);
    
    % Setup Parameters
    strength_factor = job.Emax;
    pump_speed      = job.RPM;
    Rsp_Gain_Factor = job.AL;
    Rep_Gain_Factor = job.AL;
    Vusv_Gain_Factor = job.PL;
    
    fprintf('[%d/%d] Retrying: %s ... ', k, num_missing, job.ID);
    
    success = false;
    
    % --- ATTEMPT 1: Normal Simulation ---
    try
        sim_tic = tic;
        sim('modelv3_1');
        sim_time = toc(sim_tic);
        success = true;
    catch
        % Silent catch, proceed to failure handling
    end
    
    if success
        % --- Extract & Save (Success) ---
        try
            simData = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink);
            oscData = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, Qpump, dQpump, simData.HR);
            
            result = struct();
            result.ID = job.ID; result.Inputs = job;
            result.Features.FFT_H1 = oscData.H1; result.Features.FFT_H2 = oscData.H2;
            result.Features.PumpFlow = oscData.Qpump; result.Features.dPumpFlow = oscData.dQpump;
            result.Features.dQ_H1 = oscData.dQ_H1; result.Features.dQ_H2 = oscData.dQ_H2;
            result.Features.MAP = oscData.MAP; result.Features.SBP = oscData.SBP; result.Features.DBP = oscData.DBP;
            % Raw signals for post-processing
            result.Signals.P     = P;
            result.Signals.P_all = P_all;
            result.Signals.Qpump = Qpump;
            result.Signals.Psa   = Psa_log;
            result.Signals.Plv   = Plv_log;
            
            save(filename, '-struct', 'result');
            fprintf('FIXED! (%.1fs)\n', sim_time);
            
        catch
            success = false; % Extraction failed
        end
    end
    
    if ~success
        % --- PERMANENT FAILURE ---
        % Save a "Ghost" file full of NaNs so we don't try again.
        fprintf('FAILED AGAIN. Marking as dead.\n');
        
        result = struct();
        result.ID = job.ID;
        result.Inputs = job;
        
        % NaN Features
        result.Features.FFT_H1 = NaN; result.Features.FFT_H2 = NaN;
        result.Features.PumpFlow = NaN; result.Features.dPumpFlow = NaN;
        result.Features.dQ_H1 = NaN; result.Features.dQ_H2 = NaN;
        result.Features.MAP = NaN; result.Features.SBP = NaN; result.Features.DBP = NaN;
        
        % Empty Signals
        result.Signals.P = []; result.Signals.P_all = [];
        result.Signals.Psa = []; result.Signals.Qpump = []; result.Signals.Plv = [];
        
        save(filename, '-struct', 'result');
    end
end

fprintf('\nRetry Session Complete. All holes filled (either with data or NaNs).\n');
