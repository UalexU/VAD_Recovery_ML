%% ============================================================
%   QUICK TEST: Build a Tiny Distributed ML Database
%   This is a MINIMAL version of Build_ML_Database.m
%   designed to test SHARED DRIVE logic and multi-computer sync.
%
%   Grid: 3 Emax x 3 RPM x 3 Afterload x 3 Preload = 81 sims
% ============================================================

clc; close all;

%% Setup
addpath('../..'); % For model and constants
addpath(genpath('../../modules'));

global BASENAME
BASENAME = 'modelv3/Interface/';

HeartConstantsv3;

%% ============================================================
%                  OUTPUT SETUP
% ============================================================

% --- CHANGE THIS TO YOUR SHARED DRIVE PATH ---
% Leave empty '' to use local Data/Quick_Test
SHARED_DRIVE_PATH = ''; 

if isempty(SHARED_DRIVE_PATH)
    base_folder = fullfile('../..', 'Data', 'Quick_Test');
else
    base_folder = fullfile(SHARED_DRIVE_PATH, 'Quick_Test');
end

sim_folder = fullfile(base_folder, 'simulations');
if ~exist(sim_folder, 'dir'), mkdir(sim_folder); end

%% ============================================================
%   TINY SWEEP GRID (81 simulations)
% ============================================================

emax_sweep      = [0.18, 0.30, 1.0];   % One per class
rpm_sweep       = [8, 9, 10];           % Low, Mid, High
afterload_sweep = [0.5, 1.0, 3.0];     % Low, Normal, High
preload_sweep   = [0.5, 1.0, 1.5];     % Low, Normal, High (Vusv gain)

%% ============================================================
%                  GENERATE & SHUFFLE JOBS
% ============================================================

jobs = struct('Emax', {}, 'RPM', {}, 'AL', {}, 'PL', {}, 'ID', {});

for e = emax_sweep
    for r = rpm_sweep
        for a = afterload_sweep
            for p = preload_sweep
                id = sprintf('Quick_Emax%.2f_RPM%.1f_AL%.2f_PL%.1f', e, r, a, p);
                new_job.Emax = e;
                new_job.RPM  = r;
                new_job.AL   = a;
                new_job.PL   = p;
                new_job.ID   = id;
                jobs(end+1) = new_job; %#ok<SAGROW>
            end
        end
    end
end

total_jobs = numel(jobs);
rng('shuffle'); % Shuffle differently on each computer
jobs = jobs(randperm(total_jobs));

fprintf('Quick Test: %d simulations (Distributed Mode)\n', total_jobs);
fprintf('Output: %s\n\n', sim_folder);

%% Fixed parameters
pump_on = 1;
threshold = 0.25;
Vuev_Gain_Factor = 1;

%% ============================================================
%                    MAIN SIMULATION LOOP
% ============================================================

t_start = tic;
completed_this_session = 0;

for i = 1:total_jobs
    job = jobs(i);
    
    % --- 1. Check if Already Done (The SHARED DRIVE handshake) ---
    filename = fullfile(sim_folder, ['Result_' job.ID '.mat']);
    if isfile(filename)
        continue; % Skip!
    end
    
    % --- 2. Set Parameters ---
    strength_factor  = job.Emax;
    pump_speed       = job.RPM;
    Rsp_Gain_Factor  = job.AL;
    Rep_Gain_Factor  = job.AL;
    Vusv_Gain_Factor = job.PL;

    fprintf('[%d/%d] %s ... ', i, total_jobs, job.ID);

    % --- 3. Run Simulation ---
    try
        sim_tic = tic;
        sim('modelv3_1');
        sim_time = toc(sim_tic);
    catch ME
        fprintf('FAILED (%s)\n', ME.message);
        continue;
    end

    % --- 4. Extract Features ---
    simData = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink);
    oscData = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, ...
                                   Qpump, dQpump, simData.HR);

    result = struct();
    result.Inputs = job;
    result.Features.FFT_H1    = oscData.H1;
    result.Features.FFT_H2    = oscData.H2;
    result.Features.PumpFlow  = oscData.Qpump;
    result.Features.dPumpFlow = oscData.dQpump;
    result.Features.MAP       = oscData.MAP;
    result.Features.SBP       = oscData.SBP;
    result.Features.DBP       = oscData.DBP;

    % --- 5. Raw signals for post-processing ---
    result.Signals.P     = P;
    result.Signals.P_all = P_all;
    result.Signals.Qpump = Qpump;
    result.Signals.Psa   = Psa_log;

    % --- 6. Save Result (Makes it visible to other PCs) ---
    save(filename, '-struct', 'result');
    
    fprintf('Done (%.1fs)\n', sim_time);
    completed_this_session = completed_this_session + 1;
end

%% ============================================================
%   COMPILE LOCAL CSV (For immediate testing in Step 2)
% ============================================================

fprintf('\nCompiling results into QuickTest_Database.csv...\n');
files = dir(fullfile(sim_folder, 'Result_Quick_*.mat'));
all_data = [];

for f = 1:length(files)
    data = load(fullfile(files(f).folder, files(f).name));
    row = [data.Inputs.Emax, data.Inputs.RPM, data.Inputs.AL, data.Inputs.PL, ...
           data.Features.FFT_H1, data.Features.FFT_H2, data.Features.PumpFlow, ...
           data.Features.dPumpFlow, data.Features.MAP, data.Features.SBP, data.Features.DBP];
    all_data = [all_data; row]; %#ok<AGROW>
end

col_names = {'Emax', 'RPM', 'Afterload', 'Preload', ...
             'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', ...
             'MAP', 'SBP', 'DBP'};

ML_Table = array2table(all_data, 'VariableNames', col_names);

% Add condition labels
Condition = zeros(height(ML_Table), 1);
Condition(ML_Table.Emax >= 0.25 & ML_Table.Emax < 0.6) = 1;
Condition(ML_Table.Emax >= 0.6) = 2;
ML_Table.Condition = Condition;

csv_file = fullfile(base_folder, 'QuickTest_Database.csv');
writetable(ML_Table, csv_file);

fprintf('All done! Session processed %d sims.\n', completed_this_session);
fprintf('Total files in shared folder: %d\n', length(files));
fprintf('Master CSV updated: %s\n', csv_file);
