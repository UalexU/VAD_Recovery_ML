%% ============================================================
%   ML EXPERIMENT: Test Digital Twins (Monte Carlo)
%   Generates N random "patient" scenarios (Digital Twins) and
%   tests if the trained ML model correctly classifies them.
% ============================================================

clc; close all;

%% Add helper function folder
addpath(genpath('../modules'));

%% Global model path
global BASENAME
BASENAME = 'modelv3/Interface/';

%% Load constants
HeartConstantsv3;

%% Load Trained Model
% Assumes you have already run Train_Test_Models.m or have a saved model
% For this script, we will TRAIN a model on the fly using the Master DB
% if available, otherwise we will mock it for demonstration.

master_db_file = fullfile('Data', 'ML_Database', 'ML_Master_Database.csv');
if isfile(master_db_file)
    fprintf('Loading Master Database for Training...\n');
    T_train = readtable(master_db_file);
    
    % Define Classes based on Emax
    % 0=Failing (<0.25), 1=Recovery (0.25-0.6), 2=Normal (>0.6)
    T_train.Condition = zeros(height(T_train), 1);
    T_train.Condition(T_train.Emax >= 0.25 & T_train.Emax < 0.6) = 1;
    T_train.Condition(T_train.Emax >= 0.6) = 2;
    
    % Train simple KNN
    features_train = [T_train.PumpFlow, T_train.dPumpFlow, T_train.FirstFFT, T_train.SecondFFT, T_train.DeltaP];
    target_train   = T_train.Condition;
    
    trained_model = fitcknn(features_train, target_train, 'NumNeighbors', 5, 'Standardize', true);
    fprintf('Model Trained on %d grid samples.\n', height(T_train));
else
    error('Master Database not found. Run Build_ML_Database.m first.');
end

%% ============================================================
%                MONTE CARLO CONFIGURATION
% ============================================================
num_twins = 50; % Number of random patients to simulate

% Ranges from notes
% Emax Zones (25% tolerance)
emax_centers = [0.18, 0.30, 1.0];
emax_tolerance = 0.25; % 25% variation

% Preload (Vt0) - Scaling Baseline 5100 ml
pl_min_scale = 0.1;
pl_max_scale = 1.9;
vt0_baseline = 5100;

% Afterload (Gain Factor)
al_min = 0.05;
al_max = 5.0;

% RPM
rpm_min = 8;
rpm_max = 10;

%% ============================================================
%                  DIGITAL TWIN SIMULATION
% ============================================================

results_log = [];

fprintf('\nGenerating %d Digital Twins...\n', num_twins);
progress_bar = waitbar(0, 'Simulating Digital Twins...');

for i = 1:num_twins
    waitbar(i/num_twins, progress_bar, sprintf('Twin %d/%d', i, num_twins));
    
    % --- 1. Randomize Parameters ---
    
    % Pick a class (Failing, Recovery, Normal) with equal probability
    true_class = randi([0, 2]); 
    if true_class == 0
        center = 0.18; % Failing
    elseif true_class == 1
        center = 0.30; % Recovery
    else
        center = 1.0;  % Normal
    end
    
    % Emax: Randomize within +/- 25% of the center value?
    % Notes say "25% tolerance range". 
    % Let's assume +/- 10% absolute variation for now to keep distinct clusters
    % or +/- 25% relative.
    % 0.18 +/- 25% = [0.135, 0.225]
    % 0.30 +/- 25% = [0.225, 0.375] -> Overlap at 0.225! 
    % We will stick to the generated clusters.
    
    delta = center * 0.20; % 20% relative variation
    strength_factor = center + (rand() * 2 * delta) - delta;
    
    % Preload (Vt0): Uniform [10%, 190%] of baseline
    pl_scale = pl_min_scale + (rand() * (pl_max_scale - pl_min_scale));
    Vt0 = vt0_baseline * pl_scale;
    
    % Afterload (Gain): Uniform [0.05, 5.0]
    gain = al_min + (rand() * (al_max - al_min));
    Rsp_Gain_Factor = gain;
    Rep_Gain_Factor = gain;
    
    % RPM: Uniform [8, 10]
    pump_speed = rpm_min + (rand() * (rpm_max - rpm_min));
    
    % Fixed
    pump_on = 1;
    
    % --- 2. Run Simulation ---
    try
        sim('modelv3_1');
    catch
        fprintf('  Twin %d failed (Unstable). Skipping.\n', i);
        continue;
    end
    
    % --- 3. Extract Features ---
    simData = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink);
    oscData = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, Qpump, dQpump, simData.HR);
    
    % Feature Vector (Must match training order)
    % [PumpFlow, dPumpFlow, FirstFFT, SecondFFT, DeltaP]
    feat_vector = [oscData.Qpump, oscData.dQpump, oscData.H1, oscData.H2, oscData.DeltaPsa];
    
    % --- 4. Predict ---
    predicted_class = predict(trained_model, feat_vector);
    
    % --- 5. Log Result ---
    % Columns: [TrueEmax, TrueClass, PredictedClass, RPM, Afterload, Preload, IsCorrect]
    is_correct = (predicted_class == true_class);
    
    row = [strength_factor, true_class, predicted_class, pump_speed, gain, Vt0, is_correct];
    results_log = [results_log; row]; %#ok<AGROW>
    
end
close(progress_bar);

%% ============================================================
%                  EVALUATION
% ============================================================

res_table = array2table(results_log, ...
    'VariableNames', {'Emax', 'TrueClass', 'PredictedClass', 'RPM', 'Afterload', 'Preload', 'IsCorrect'});

accuracy = mean(res_table.IsCorrect) * 100;
fprintf('\n=== TEST RESULTS ===\n');
fprintf('Overall Accuracy: %.2f%%\n', accuracy);

% Confusion Matrix
figure('Name', 'Digital Twin Classification');
confusionchart(res_table.TrueClass, res_table.PredictedClass, ...
    'RowSummary','row-normalized', 'ColumnSummary','column-normalized');
title(sprintf('Digital Twin Test (N=%d, Acc=%.1f%%)', height(res_table), accuracy));

% Save Results
output_file = fullfile('Data', 'ML_Experiments', 'Digital_Twin_Results.csv');
writetable(res_table, output_file);
fprintf('Detailed results saved to: %s\n', output_file);
