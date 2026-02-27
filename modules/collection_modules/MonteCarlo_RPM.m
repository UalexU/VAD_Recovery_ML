%% -----------------------------------------------------
%  Graphic of Delta Pressure as EMax and RPM increase
% ------------------------------------------------------

clc; clear; close all;

%% Load CSVs Preload
T_normal   = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\RPM\Sweep_RPM_ExtendedNormal_PumpOn_10.csv');
T_recovery = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\RPM\Sweep_RPM_ExtendedRecovery_PumpOn_10.csv');
T_failing  = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\RPM\Sweep_RPM_ExtendedFailing_PumpOn_10.csv');

% Boundaries Definition 

Emax_min = 0.18; Emax_max = 1.0;
RPM_min  = 8.00; RPM_max  = 10.0; % This can change

%% Extract outputs



%% Analyze distributions
% figure;
% subplot(3,1,1);
% histogram(MC_samples.Psa_mean,50);
% xlabel('Emax'); ylabel(''); title('');
% 
% subplot(3,1,2);
% histogram(MC_samples.Plv_min,50);
% xlabel(''); ylabel(''); title('');
% 
% subplot(3,1,3);
% histogram(MC_samples.CO,50);
% xlabel(''); ylabel(''); title('')

figure
scatter3(T_normal.Strength_factor_value, T_normal.RPM_speed_, T_normal.DeltaPlv, 'filled');
xlabel('Emax'); ylabel('RPM(speed)'); zlabel('Delta Pressure');

% 3D bar
bar3_data = [T_normal.Strength_factor_value, T_normal.RPM_speed_, T_normal.DeltaPlv];
figure;
bar3(bar3_data);
xlabel('Emax'); ylabel('RPM(speed)'); zlabel('Delta Pressure');
title('3D Bar Graph of Delta Pressure vs EMax and RPM');
colorbar;
title('');
colorbar; 

% 2D bar
bar3_data = [T_normal.Strength_factor_value, T_normal.RPM_speed_, T_normal.DeltaPlv];
figure;
bar3(bar3_data);
xlabel('Emax'); ylabel('RPM(speed)'); zlabel('Delta Pressure');
title('3D Bar Graph of Delta Pressure vs EMax and RPM');
colorbar;
title('');
colorbar; 
hold on;
scatter3(T_recovery.Strength_factor_value, T_recovery.RPM_speed_, T_recovery.DeltaPlv, 'filled', 'MarkerFaceColor', 'g');
scatter3(T_failing.Strength_factor_value, T_failing.RPM_speed_, T_failing.DeltaPlv, 'filled', 'MarkerFaceColor', 'r');
legend('Normal', 'Recovery', 'Failing');
hold off;




