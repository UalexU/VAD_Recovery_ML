%% ============================================================
%   AFTERLOAD SWEEP SCRIPT (Based on Data_Collection_Winter)
% ============================================================

clc; clear; close all;

%% Add helper function folder
addpath('..');
addpath(genpath('../modules')); % In case we are in a subfolder

%% Global model path
global BASENAME
BASENAME = 'modelv3/Interface/';

%% Load constants
HeartConstantsv3;

%% Sweep parameters
% Sweep Rsp (Systemic Resistance) from 50% to 500%
afterload_sweep = 0.5:0.5:5.0; 
strength_levels  = [1, 0.3]; 

%% Fixed parameters
pump_speed = 9000; % Fixed RPM
pump_on = 1;
threshold = 0.25;
Vusv_Gain_Factor = 1;
Vuev_Gain_Factor = 1;

%% Scenario label
scenario = 'Afterload_Sweep_Winter';

%% Reset cuff pressure master file
cuffFile = sprintf('Data/CuffPressure_Master_%s.csv', scenario);
if isfile(cuffFile)
    delete(cuffFile);
end

%% ============================================================
%                 MAIN SWEEP OVER STRENGTH LEVELS
% ============================================================

% Initialize matrices for 3D plotting
num_s = length(strength_levels);
num_k = length(afterload_sweep);

MAP_Matrix           = zeros(num_s, num_k);
PumpFlow_Matrix      = zeros(num_s, num_k);
dPumpFlow_Matrix     = zeros(num_s, num_k);
DeltaPumpP_Matrix    = zeros(num_s, num_k);

for s = 1:num_s

    strength_factor = strength_levels(s);
    n = num_k;

    % Preallocate results
    results = initResultStruct(n, strength_factor);

    %% ============================================================
    %                     SWEEP LOOP
    % ============================================================
    for k = 1:n

        % Set Afterload
        Rsp_Gain_Factor = afterload_sweep(k);
        Rep_Gain_Factor = afterload_sweep(k); % Usually scaled together
        
        % Run simulation
        sim('modelv3_1');
        
        % Extract simulation outputs
        simData = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink);

        % Extract oscillometric + FFT + peak info
        oscData = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, Qpump, dQpump, simData.HR);

        % Store results (Pass afterload as 6th argument)
        results = storeResults(results, simData, oscData, pump_speed, k, afterload_sweep(k));

    end

    %% ============================================================
    %               CLASSIFY MAP + SAVE RESULTS
    % ============================================================
    results.MAP_classification = classifyMAP(results.Psa_mean);

    % Accumulate data for plotting
    MAP_Matrix(s, :)        = results.Psa_mean;
    PumpFlow_Matrix(s, :)   = results.PumpFlow;
    dPumpFlow_Matrix(s, :)  = results.dPumpFlow;
    DeltaPumpP_Matrix(s, :) = results.DeltaPumpPressure;

    saveSweepResults(results, strength_factor, pump_speed, scenario);

end

%% ============================================================
%                   VISUALIZATION
% ============================================================
base_folder = fullfile('Data', 'Figures', 'Afterload', scenario);
folder_3D      = fullfile(base_folder, '3D_Bar_Charts');
if ~exist(folder_3D, 'dir'), mkdir(folder_3D); end

fprintf('Generating organized plots in: %s\n', base_folder);

plot3DBarFeatures(strength_levels, afterload_sweep, PumpFlow_Matrix,      'Pump Flow Pulsatility (ml/s)', folder_3D);
plot3DBarFeatures(strength_levels, afterload_sweep, dPumpFlow_Matrix,     'Flow Derivative Pulsatility (dQF)', folder_3D);
plot3DBarFeatures(strength_levels, afterload_sweep, DeltaPumpP_Matrix,    'Delta Simulation Pump Pressure (mmHg)', folder_3D);

fprintf('Sweep complete for scenario: %s\n', scenario);
