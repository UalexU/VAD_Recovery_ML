%% ============================================================
%   QUICK TEST: Build a Tiny ML Database
%   This is a MINIMAL version of Build_ML_Database.m
%   designed to run in ~10-20 minutes for rapid prototyping.
%
%   Grid: 3 Emax x 3 RPM x 3 Afterload x 3 Preload = 81 sims
% ============================================================

clc; close all;

%% Setup
addpath(genpath('../modules'));

global BASENAME
BASENAME = 'modelv3/Interface/';

HeartConstantsv3;

%% ============================================================
%   TINY SWEEP GRID (81 simulations)
% ============================================================

emax_sweep      = [0.18, 0.30, 1.0];   % One per class
rpm_sweep       = [8, 9, 10];           % Low, Mid, High
afterload_sweep = [0.5, 1.0, 3.0];     % Low, Normal, High
preload_sweep   = [0.5, 1.0, 1.5];     % Low, Normal, High (Vusv gain)

total_sims = numel(emax_sweep) * numel(rpm_sweep) * ...
             numel(afterload_sweep) * numel(preload_sweep);
fprintf('Quick Test: %d simulations\n\n', total_sims);

%% Fixed parameters
pump_on = 1;
threshold = 0.25;
Vuev_Gain_Factor = 1;

%% Output
sim_folder = fullfile('Data', 'Quick_Test');
if ~exist(sim_folder, 'dir'), mkdir(sim_folder); end

%% ============================================================
%   RUN ALL SIMULATIONS
% ============================================================

all_rows = [];
sim_count = 0;
t_start = tic;

for e = emax_sweep
    for r = rpm_sweep
        for a = afterload_sweep
            for p = preload_sweep

                sim_count = sim_count + 1;

                % Set parameters
                strength_factor  = e;
                pump_speed       = r;
                Rsp_Gain_Factor  = a;
                Rep_Gain_Factor  = a;
                Vusv_Gain_Factor = p;

                sim_id = sprintf('Emax%.2f_RPM%.1f_AL%.2f_PL%.1f', e, r, a, p);
                fprintf('[%d/%d] %s ... ', sim_count, total_sims, sim_id);

                % Run simulation
                try
                    sim_tic = tic;           % Start stopwatch
                    sim('modelv3_1');         % Run Simulink model
                    sim_time = toc(sim_tic); % Read stopwatch (seconds)
                catch ME
                    fprintf('FAILED (%s)\n', ME.message);
                    continue;
                end

                % Extract features
                simData = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink);
                oscData = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, ...
                                               Qpump, dQpump, simData.HR);

                % Build row: [Inputs | Features]
                row = [e, r, a, p, ...
                       oscData.H1, oscData.H2, ...
                       oscData.Qpump, oscData.dQpump, ...
                       oscData.MAP, oscData.SBP, oscData.DBP];

                all_rows = [all_rows; row]; %#ok<AGROW>
                fprintf('Done (%.1fs)\n', sim_time);
            end
        end
    end
end

elapsed = toc(t_start);
fprintf('\nAll done! %d sims in %.1f min\n', size(all_rows, 1), elapsed/60);

%% ============================================================
%   SAVE DATASET
% ============================================================

col_names = {'Emax', 'RPM', 'Afterload', 'Preload', ...
             'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', ...
             'MAP', 'SBP', 'DBP'};

ML_Table = array2table(all_rows, 'VariableNames', col_names);

% Add condition labels
Condition = zeros(height(ML_Table), 1);
Condition(ML_Table.Emax >= 0.25 & ML_Table.Emax < 0.6) = 1;
Condition(ML_Table.Emax >= 0.6) = 2;
ML_Table.Condition = Condition;

csv_file = fullfile(sim_folder, 'QuickTest_Database.csv');
mat_file = fullfile(sim_folder, 'QuickTest_Database.mat');
writetable(ML_Table, csv_file);
save(mat_file, 'ML_Table');

fprintf('Saved to: %s\n', csv_file);
fprintf('\nClass Distribution:\n');
fprintf('  Failing  (0): %d\n', sum(Condition == 0));
fprintf('  Recovery (1): %d\n', sum(Condition == 1));
fprintf('  Normal   (2): %d\n', sum(Condition == 2));
