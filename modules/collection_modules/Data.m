clear all;
clc;

global BASENAME
BASENAME = 'modelv3/Interface/';


HeartConstantsv3;  % Load constants

% Simulation parameters
pump_on = 1; % Off - 0 On - 1
pump_speed = 8;
threshold = 0.25;
strength_factor = 1; %1 Normal Heart, 0.3 Recovery Heart, 0.18 Failure Heart

% Define the gain variable in the MATLAB base workspace
Rep_Gain_Factor = 2;
Rsp_Gain_Factor = 2;
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
