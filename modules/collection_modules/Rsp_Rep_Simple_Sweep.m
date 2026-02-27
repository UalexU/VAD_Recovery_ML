% Rsp and Rep sweep 

clc;
clear all; 

global BASENAME
BASENAME = 'modelv3/Interface/';

% --- Load constants ---
HeartConstantsv3;   % sets default constants

% Define sweep range for Rpv
Sweep_values_Rsp_Rep = 0.2:0.025:0.4; %Afterload
Rsp_values = Sweep_values_Rsp_Rep; 
Rep_values = Sweep_values_Rsp_Rep;


% Rsp_base = Rsp;
% Rep_base = Rep;
% Define the gain variable in the MATLAB base workspace (1 default)
Rep_Gain_Factor = 1;
Rsp_Gain_Factor = 1;
Vusv_Gain_Factor = 1;
Vuev_Gain_Factor = 1;


Rpv = 0.0056;
% Preallocate results
Psa_mean_results = zeros(size(Sweep_values_Rsp_Rep));
Psa_max_results = zeros(size(Sweep_values_Rsp_Rep));
Prv_max_results = zeros(size(Sweep_values_Rsp_Rep));
Plv_max_results = zeros(size(Sweep_values_Rsp_Rep));
Plv_min_results = zeros(size(Sweep_values_Rsp_Rep));
Strength_factor_value = zeros(size(Sweep_values_Rsp_Rep));
CO_results = zeros(size(Sweep_values_Rsp_Rep));
HR_results = zeros(size(Sweep_values_Rsp_Rep));
SV_results = zeros(size(Sweep_values_Rsp_Rep));
PO_results = zeros(size(Sweep_values_Rsp_Rep));

for k = 1:length(Sweep_values_Rsp_Rep)

    
    % Overwrite the parameter to sweep
    % For afterload sweep
    Rep_Gain_Factor = Sweep_values_Rsp_Rep(k);
    Rsp_Gain_Factor = Sweep_values_Rsp_Rep(k);
    % Simulation parameters
    pump_on = 0; % Off - 0 On - 1
    pump_speed = 10;
    threshold = 0.25;
    strength_factor = 1; %1 Normal Heart, 0.3 Recovery Heart, 0.18 Failure Heart

    %  % Set up simulation input with stop time
    % simIn = Simulink.SimulationInput('modelv3_1');
    % simIn = simIn.setModelParameter('StopTime', '80');

    % Run the simulation 
    % simOut = sim(simIn);
    sim('modelv3_1');

    CO = CO_sim(end,1);
    HR = HR_sim(end,1);
    SV = SV_sim(end,1);
    PO = PO_sim(end,1);
    
    % --- Extract peaks ---
    [Psa_max, ~, ~, ~, ~] = getPeakInfo(Psa_log);
    [Prv_max, ~, ~, ~, ~] = getPeakInfo(Prv_log);
    [Plv_max, ~, ~, Plv_min,~, ~] = getPeakInfo(Plv_log);
    

    % --- Store results ---
    Psa_mean_results(k) = Psa_mean_from_simulink(end);
    Psa_max_results(k) = Psa_max;
    Prv_max_results(k) = Prv_max;
    Plv_max_results(k) = Plv_max;
    Plv_min_results(k) = Plv_min;
    Strength_factor_value(k) = strength_factor;
    CO_results(k) = CO;
    HR_results(k) = HR;
    SV_results(k) = SV;
    PO_results(k) = PO;
end

% Save results (if name change, modify also csv file name)
save('Data/Sweep/Afterload/Sweep_Rsp_Rep_Pumpmin_Normal_hypo.mat', 'Strength_factor_value','Sweep_values_Rsp_Rep', 'Psa_max_results','Psa_mean_results', 'Prv_max_results', 'Plv_max_results','Plv_min_results', 'CO_results', 'HR_results', 'SV_results', 'PO_results');
% Create a table
resultsTable = table( ...
    Strength_factor_value(:), ...
    Rsp_values(:), ...
    Rep_values(:), ...
    Psa_max_results(:), ...
    Psa_mean_results(:), ...
    Prv_max_results(:), ...
    Plv_max_results(:), ...
    Plv_min_results(:), ...
    CO_results(:), ...
    HR_results(:), ...
    SV_results(:), ...
    PO_results(:), ...
    'VariableNames', {'Strength_factor_value','Rsp', 'Rep', 'Psa_max', 'Psa_mean', 'Prv_max', 'Plv_max','Plv_min', 'CO', 'HR', 'SV', 'PO'});

% Make table with csv
writetable(resultsTable, 'Data/Sweep/Afterload/Sweep_Rsp_Rep_Pumpmin_Normal_hypo.csv');
