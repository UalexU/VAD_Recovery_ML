%% -----------------------------------------------------
%  ORIGINAL POINTS VISUALIZATION (PUMP OFF)
% ------------------------------------------------------

clc; clear; close all;

%% Load CSVs Preload
T_normal   = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\Preload\VusvSweep_Normal_PumpOff_8.csv');
T_recovery = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\Preload\VusvSweep_Recovery_PumpOff_8.csv');
T_failing  = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\Preload\VusvSweep_Failing_PumpOff_8.csv');

% Combine datasets
T_all = [T_normal; T_recovery; T_failing];

%% Boundaries Definition
Emax_min = 0.18; Emax_max = 1.0;
Vusv_min = 0; Vusv_max = 2000; % adjust if needed

% Filter dataset within boundaries
T_filtered = T_all(T_all.Strength_factor_value >= Emax_min & ...
                   T_all.Strength_factor_value <= Emax_max & ...
                   T_all.Vusv >= Vusv_min & ...
                   T_all.Vusv <= Vusv_max, :);

%% Scatter plot of original points
figure;
scatter3(T_filtered.Strength_factor_value, ...
         T_filtered.Vusv, ...
         T_filtered.CO, ...
         50, T_filtered.Psa_mean, 'filled');

xlabel('E_{max}', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Vusv', 'FontSize', 12, 'FontWeight', 'bold');
zlabel('CO', 'FontSize', 12, 'FontWeight', 'bold');
title('Cardiovascular Output Across Contractility and Preload', ...
      'FontSize', 14, 'FontWeight', 'bold');

colormap jet;
colorbar;
grid on;
view(45,30);
