%% ============================================================
%   ML EXPERIMENT: Generate Focused Dataset
%   Generates small, targeted datasets to test feature separability
%   without running the full 4D simulation matrix.
% ============================================================

clc; close all;

%% Add helper function folder
addpath(genpath('../modules'));

%% Global model path
global BASENAME
BASENAME = 'modelv3/Interface/';

%% Load constants
HeartConstantsv3;

%% ============================================================
%              EXPERIMENT CONFIGURATION
%   Choose ONE experiment to run by uncommenting it.
% ============================================================

% --- EXP 1: Preload Separability (Fixed Afterload/RPM) ---
experiment_name = 'Exp1_Preload_Separability';
emax_levels     = [0.18, 0.3, 1.0]; % Failing, Recovery, Normal
preload_sweep   = 3500:500:24000;   % High resolution preload
afterload_fixed = 1;
rpm_fixed       = 9;

% --- EXP 2: Afterload Separability (Fixed Preload/RPM) ---
% experiment_name = 'Exp2_Afterload_Separability';
% emax_levels     = [0.18, 0.3, 1.0];
% preload_fixed   = 5100;
% afterload_sweep = 1:0.5:10;
% rpm_fixed       = 9;

%% Fixed parameters
pump_on = 1;
threshold = 0.25;
Vusv_Gain_Factor = 1;
Vuev_Gain_Factor = 1;

%% Output Setup
output_folder = fullfile('Data', 'ML_Experiments', experiment_name);
if ~exist(output_folder, 'dir'), mkdir(output_folder); end
csv_file = fullfile(output_folder, 'dataset.csv');

%% ============================================================
%                    SIMULATION LOOP
% ============================================================

feature_names = {'Emax', 'Condition', 'RPM', 'Afterload', 'Preload', ...
                 'PumpFlow_Pulsatility', 'dPumpFlow_Pulsatility', ...
                 'DeltaPumpPressure', 'MAP', 'CO', 'MeanPumpPressure'};

data_rows = [];

fprintf('Running Experiment: %s\n', experiment_name);

for i_emax = 1:numel(emax_levels)
    strength_factor = emax_levels(i_emax);
    
    % Define Condition Label
    if strength_factor < 0.25
        cond_label = 0; % Failing
        cond_str = 'Failing';
    elseif strength_factor < 0.6
        cond_label = 1; % Recovery
        cond_str = 'Recovery';
    else
        cond_label = 2; % Normal
        cond_str = 'Normal';
    end
    
    % Handle different experiment types
    if contains(experiment_name, 'Preload')
        iter_vec = preload_sweep;
        fprintf('  Simulating %s heart (Preload sweep)...\n', cond_str);
    else
        iter_vec = afterload_sweep;
        fprintf('  Simulating %s heart (Afterload sweep)...\n', cond_str);
    end
    
    for k = 1:numel(iter_vec)
        
        % Set parameters based on experiment type
        if contains(experiment_name, 'Preload')
            Vt0 = iter_vec(k);
            Rsp_Gain_Factor = afterload_fixed;
            Rep_Gain_Factor = afterload_fixed;
            pump_speed = rpm_fixed;
            current_al = afterload_fixed;
            current_pl = Vt0;
        else
            Vt0 = preload_fixed;
            Rsp_Gain_Factor = iter_vec(k);
            Rep_Gain_Factor = iter_vec(k);
            pump_speed = rpm_fixed;
            current_al = iter_vec(k);
            current_pl = Vt0;
        end
        
        % Run Sim
        try
            sim('modelv3_1');
        catch
            fprintf('    Failed at PL=%d AL=%.1f\n', current_pl, current_al);
            continue;
        end
        
        % Extract Data
        simData = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink);
        oscData = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, Qpump, dQpump, simData.HR);
        
        pumpP_signal = oscData.Psa(:,2) - oscData.Plv(:,2);
        
        % Store Row
        row = [strength_factor, cond_label, pump_speed, current_al, current_pl, ...
               oscData.Qpump, ...             % Pump Flow Pulsatility
               oscData.dQpump, ...            % dPumpFlow Pulsatility
               max(pumpP_signal) - min(pumpP_signal), ... % Delta Pump Pressure
               oscData.MAP, ...
               simData.CO, ...
               mean(pumpP_signal)];
           
        data_rows = [data_rows; row]; %#ok<AGROW>
        
    end
end

%% ============================================================
%                    SAVE DATASET
% ============================================================

T = array2table(data_rows, 'VariableNames', feature_names);
writetable(T, csv_file);

fprintf('\nExperiment Complete!\n');
fprintf('Dataset saved to: %s\n', csv_file);
fprintf('Total samples: %d\n', height(T));

%% ============================================================
%                    QUICK VISUALIZATION
% ============================================================
figure('Name', 'Feature Separability', 'Color', 'w');
gscatter(T.PumpFlow_Pulsatility, T.dPumpFlow_Pulsatility, T.Condition, 'rbg', 'xo^');
xlabel('Pump Flow Pulsatility (ml/s)');
ylabel('Flow Derivative Pulsatility (dQF)');
title(['Feature Space: ' experiment_name], 'Interpreter', 'none');
legend({'Failing', 'Recovery', 'Normal'});
grid on;

saveas(gcf, fullfile(output_folder, 'feature_scatter.png'));
