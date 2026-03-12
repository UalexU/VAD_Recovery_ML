%% ============================================================
%   PRELOAD SWEEP SCRIPT (Based on Data_Collection_Winter)
% ============================================================

clc; clear; close all;

%% Add helper function folder
addpath('..');
addpath(genpath('../modules'));

%% Global model path
global BASENAME
BASENAME = 'modelv3/Interface/';

%% Load constants
HeartConstantsv3;

%% Sweep parameters
% Sweep Vusv (Unstressed Venous Volume) from 10% to 190%
preload_sweep = 0.1:0.2:1.9; 
strength_levels  = [1, 0.3]; 

%% Fixed parameters
pump_speed = 9000; % Fixed RPM
pump_on = 1;
threshold = 0.25;
Rsp_Gain_Factor = 1;
Rep_Gain_Factor = 1;

%% Scenario label
scenario = 'Preload_Sweep_Winter';

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
num_k = length(preload_sweep);

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

        % Set Preload (Vusv Gain)
        Vusv_Gain_Factor = preload_sweep(k);
        
        % Run simulation
        sim('modelv3_1');
        
        % Extract simulation outputs
        simData = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink);

        % Extract oscillometric + FFT + peak info
        oscData = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, Qpump, dQpump, simData.HR);

        % Store results (Pass preload as 7th argument, afterload is default 1)
        results = storeResults(results, simData, oscData, pump_speed, k, 1, preload_sweep(k));

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
base_folder = fullfile('Data', 'Figures', 'Preload', scenario);
folder_3D      = fullfile(base_folder, '3D_Bar_Charts');
if ~exist(folder_3D, 'dir'), mkdir(folder_3D); end

fprintf('Generating organized plots in: %s\n', base_folder);

plot3DBarFeatures(strength_levels, preload_sweep, PumpFlow_Matrix,      'Pump Flow Pulsatility (ml/s)', folder_3D);
plot3DBarFeatures(strength_levels, preload_sweep, dPumpFlow_Matrix,     'Flow Derivative Pulsatility (dQF)', folder_3D);
plot3DBarFeatures(strength_levels, preload_sweep, DeltaPumpP_Matrix,    'Delta Simulation Pump Pressure (mmHg)', folder_3D);

fprintf('Sweep complete for scenario: %s\n', scenario);
