clear all;
clc;

global BASENAME
BASENAME = 'modelv3/Interface/';


thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..')); % repo root: HeartConstantsv3.m, Simulink model

HeartConstantsv3;

% Simulation parameters
pump_on = 1; % Off - 0 On - 1
pump_speed = 20;
threshold = 0.25;
strength_factor = 1; %1 Normal Heart, 0.3 Recovery Heart, 0.18 Failure Heart

% Define the gain variable in the MATLAB base workspace
Rep_Gain_Factor = 1;
Rsp_Gain_Factor = 1;
Vusv_Gain_Factor = 1;
Vuev_Gain_Factor = 1;
% Rpv = 1*0.0056;
Rpv = 0.0056*1; 

% Run simulation
sim('modelv3_1');

% Extract final values 

% This was the old method 
% CO=CO_sim(length(CO_sim),1);

% This does the exact same thing — grabs the last value in the first column
CO = CO_sim(end,1);
HR = HR_sim(end,1);
SV = SV_sim(end,1);
PO = PO_sim(end,1);

% Max Psa, Min Psa, Mean Psa 
    [SBP,DBP,MAP] = Oscillometric(P,0.02)
    % Delta Psa 
    Delta_Psa = SBP - DBP; 
% Function to obtain max value, index, and time of the given log data file 
% Psa max
[Psa_max, Psa_max_index, Psa_max_time, Psa_min, Psa_min_index, Psa_min_time] = getPeakInfo(Psa_log);
% Prv max
[Prv_max, Prv_max_index, Prv_max_time, Prv_min, Prv_min_index, Prv_min_time] = getPeakInfo(Prv_log);
% Plv max
[Plv_max, Plv_max_index, Plv_max_time, Plv_min, Plv_min_index, Plv_min_time] = getPeakInfo(Plv_log);

% --- Plv (+ Qpump when logged): suction / strong unloading often shows very low Plv and ragged Qpump ---
figure('Name', 'Data.m: Plv and pump flow', 'Color', 'w', 'Position', [80 80 900 520]);

subplot(2, 1, 1);
plot(Plv_log(:, 1), Plv_log(:, 2), 'Color', [0 0.45 0.74], 'LineWidth', 1);
hold on;
yline(0, '--', 'Color', [0.65 0.65 0.65]);
hold off;
ylabel('Plv (mmHg)');
title(sprintf('Left ventricular pressure (min=%.1f, max=%.1f mmHg)', Plv_min, Plv_max));
grid on;

subplot(2, 1, 2);
if exist('Qpump', 'var') && ~isempty(Qpump) && size(Qpump, 2) >= 2
    plot(Qpump(:, 1), Qpump(:, 2), 'Color', [0.85 0.33 0.1], 'LineWidth', 1);
    ylabel('Flow (ml/s)');
    title('Pump flow Qpump');
else
    text(0.5, 0.5, 'Qpump not available — check Qpump scope data logging in modelv3_1', ...
        'HorizontalAlignment', 'center', 'Units', 'normalized');
    title('Pump flow Qpump');
    ylabel('Flow (ml/s)');
end
xlabel('Time (s)');
grid on;

% Save info 
outputFolder = fullfile('Data', 'Sweep');

% Create a table with single-run results
resultsTable = table( ...
    CO, HR, SV, PO, ...
    Psa_mean_from_simulink(end), ...
    Psa_max, Psa_max_time, Psa_min, Psa_min_time, ...
    Prv_max, Prv_max_time, Prv_min, Prv_min_time, ...
    Plv_max, Plv_max_time, Plv_min, Plv_min_time, ...
    'VariableNames', { ...
        'CO','HR','SV','PO', ...
        'Psa_mean_from_simulink', ...
        'Psa_max','Psa_max_time','Psa_min','Psa_min_time', ...
        'Prv_max','Prv_max_time','Prv_min','Prv_min_time', ...
        'Plv_max','Plv_max_time','Plv_min','Plv_min_time' ...
    } ...
);

% Save as MAT and CSV
save(fullfile(outputFolder, 'Single_data_results.mat'), 'resultsTable');
writetable(resultsTable, fullfile(outputFolder, 'Single_data_results.csv'));

disp('✅ Results saved to Data/Sweep.');
