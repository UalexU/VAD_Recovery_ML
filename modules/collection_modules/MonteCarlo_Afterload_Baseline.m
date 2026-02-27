%% -----------------------------------------------------
%  MONTE CARLO SIMULATION (PUMP OFF)
%  Works even if sweep points are collinear
% ------------------------------------------------------

clc; clear; close all;

%% Load CSVs Afterload
T_normal   = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\Afterload\Sweep_Afterload_ExtendedNormal_PumpOff_10.csv');
T_recovery = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\Afterload\Sweep_Afterload_ExtendedRecovery_PumpOff_10.csv');
T_failing  = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\Afterload\Sweep_Afterload_ExtendedFailing_PumpOff_10.csv');


T_all = [T_normal; T_recovery; T_failing];

% Boundaries Definition 

Emax_min = 0.18; Emax_max = 1.0;
Rsp_min  = 0.275; Rsp_max  = 2.0; % This can change

% Filter dataset within boundaries
T_filtered = T_all(T_all.Strength_factor_value >= Emax_min & ...
                   T_all.Strength_factor_value <= Emax_max & ...
                   T_all.Rsp >= Rsp_min & ...
                   T_all.Rsp <= Rsp_max, :);


%% Monte Carlo resampling
Nsim = 5000; % number of samples
idx = randi(heightb(T_filtered), Nsim, 1); % random row indices
MC_samples = T_filtered(idx,:); % Monte Carlo - MC

%% Extract outputs
Psa_mean_MC = MC_samples.Psa_mean;
Plv_min_MC  = MC_samples.Plv_min;
CO_MC       = MC_samples.CO;


%% Analyze distributions
figure;
subplot(3,1,1);
histogram(MC_samples.Psa_mean,50);
xlabel('Psa mean'); ylabel('Count'); title('Monte Carlo Distribution of Psa mean');

subplot(3,1,2);
histogram(MC_samples.Plv_min,50);
xlabel('Plv min'); ylabel('Count'); title('Monte Carlo Distribution of Plv min');

subplot(3,1,3);
histogram(MC_samples.CO,50);
xlabel('CO'); ylabel('Count'); title('Monte Carlo Distribution of CO')

figure
scatter3(T_filtered.Strength_factor_value, T_filtered.Rsp, T_filtered.CO, 50, T_filtered.Psa_mean, 'filled');
xlabel('Emax'); ylabel('Rsp'); zlabel('CO');
title('Cardiovascular Output Across Contractility and Afterload');
colorbar; 


% option 3
figure
boxplot(T_filtered.CO, T_filtered.Strength_factor_value);
xlabel('Emax'); ylabel('CO'); title('CO Distribution by Contractility');


%% Summary statistics
fprintf('Monte Carlo Results (N=%d):\n',Nsim);
fprintf('Psa_mean: mean=%.2f, std=%.2f\n', mean(Psa_mean_MC), std(Psa_mean_MC));
fprintf('Plv_min : mean=%.2f, std=%.2f\n', mean(Plv_min_MC), std(Plv_min_MC));
fprintf('CO      : mean=%.2f, std=%.2f\n', mean(CO_MC), std(CO_MC));