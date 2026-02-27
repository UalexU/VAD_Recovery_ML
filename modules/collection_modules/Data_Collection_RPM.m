clc;
clear all;
close all;

global BASENAME
BASENAME = 'modelv3/Interface/';

% --- Load constants ---
HeartConstantsv3;   % sets default constants

% Define sweep range for Rsp and Rep (Afterload)
pump_speed_sweep = 8:0.1:8.1; 

% Fixed Parameters
pump_on = 1;  % 0 = Off, 1 = On
pump_speed = 8; % 8k 
threshold = 0.25;
Rep_Gain_Factor = 1;
Rsp_Gain_Factor = 1;
Vusv_Gain_Factor = 1;
Vuev_Gain_Factor = 1;
% Heart Strength Factors: 1 = Normal, 0.3 = Recovery, 0.18 = Failing
strength_levels = [1, 0.3, 0.18];

% Scenario label for this simulation
scenario = 'PumpOn_RPMSweep';   % change per script

% Independent file for cuff pressure data
cuffFile = sprintf('Data/CuffPressure_Master_%s.csv', scenario);

if isfile(cuffFile)
    delete(cuffFile); % start fresh
end


for s = 1:length(strength_levels)
    
    strength_factor = strength_levels(s);
    
    % Preallocate result arrays
    n = length(pump_speed_sweep);
    Psa_mean_results = zeros(1, n);
    Psa_max_results = zeros(1, n);
    Prv_max_results  = zeros(1, n);
    Plv_max_results  = zeros(1, n);
    Plv_min_results  = zeros(1, n);
    CO_results       = zeros(1, n);
    HR_results       = zeros(1, n);
    SV_results       = zeros(1, n);
    PO_results       = zeros(1, n);
    DeltaPlv_results = zeros(1, n);
    RPM_values = zeros(1,n);
    Strength_factor_value = strength_factor * ones(1, n);

    % ---- Sweep Loop ----
    for k = 1:n
        % Apply sweep values
        pump_speed = pump_speed_sweep(k);
        
        % Run Simulation
        sim('modelv3_1');

        % Extract results
        CO = CO_sim(end,1);
        HR = HR_sim(end,1);
        SV = SV_sim(end,1);
        PO = PO_sim(end,1);
    
        % Extract pressure peaks
        [Psa_max, ~, ~, ~, ~] = getPeakInfo(Psa_log);
        [Prv_max, ~, ~, ~, ~] = getPeakInfo(Prv_log);
        [Plv_max, ~, ~, Plv_min, ~, ~] = getPeakInfo(Plv_log);
        DeltaPlv = Plv_max - Plv_min;
        
        % Store results
        Psa_mean_results(k) = Psa_mean_from_simulink(end);
        Psa_max_results(k)  = Psa_max;
        Prv_max_results(k)  = Prv_max;
        Plv_max_results(k)  = Plv_max;
        Plv_min_results(k)  = Plv_min;
        CO_results(k)       = CO;
        HR_results(k)       = HR;
        SV_results(k)       = SV;
        PO_results(k)       = PO;
        DeltaPlv_results(k) = DeltaPlv;
        RPM_values(k) = pump_speed;

        % ---- Save cuff pressure array independently ----
        cuffPressure = Filtered_Cuff;   % 5000x2 array from Simulink
        runID = k;
        strengthFactor = strength_factor;
        
        % Determine condition label based on strength factor
        if strengthFactor == 1.0
            condition = 'Normal';
        elseif strengthFactor == 0.3
            condition = 'Recovery';
        else
            condition = 'Failing';
        end
        
        saveCuffPressure(cuffPressure, runID, strengthFactor, pump_speed, condition, 'csv', scenario);


    end

    % ---- MAP Classification ----
    MAP_classification = strings(size(Psa_mean_results));
    for i = 1:length(Psa_mean_results)
        if Psa_mean_results(i) < 60
            MAP_classification(i) = "Out of Bounds (Low)";
        elseif Psa_mean_results(i) < 70
            MAP_classification(i) = "Hypotension";
        elseif Psa_mean_results(i) <= 125
            MAP_classification(i) = "Normal";
        elseif Psa_mean_results(i) <= 145
            MAP_classification(i) = "Hypertension";
        else
            MAP_classification(i) = "Out of Bounds (High)";
        end
    end

    % ---- Create Table ----
    resultsTable = table( ...
        Strength_factor_value(:), ...
        RPM_values(:), ...
        Psa_max_results(:), ...
        Psa_mean_results(:), ...
        MAP_classification(:), ...
        Prv_max_results(:), ...
        Plv_max_results(:), ...
        Plv_min_results(:), ...
        DeltaPlv_results(:), ...
        CO_results(:), ...
        HR_results(:), ...
        SV_results(:), ...
        PO_results(:), ...
        'VariableNames', {'Strength_factor_value','RPM(speed)','Psa_max','Psa_mean','MAP_class',...
        'Prv_max','Plv_max','Plv_min','DeltaPlv','CO','HR','SV','PO'});

    % ---- Condition Label ----
    if strength_factor == 1.0
        condition = 'Normal';
    elseif strength_factor == 0.3
        condition = 'Recovery';
    else
        condition = 'Failing';
    end

    % ---- File Naming ----
    pumpState = "PumpOn"; %Off or On can be changed
    savePath = 'Data/Sweep/RPM/';
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end

    matName = sprintf('%sSweep_RPM_Extended%s_%s_%s.mat', savePath, condition, pumpState, num2str(pump_speed));
    csvName = sprintf('%sSweep_RPM_Extended%s_%s_%s.csv', savePath, condition, pumpState, num2str(pump_speed));

    % ---- Save Results ----
    save(matName, 'Strength_factor_value', 'RPM_values', ...
        'Psa_max_results', 'Psa_mean_results', 'MAP_classification', ...
        'Prv_max_results', 'Plv_max_results', 'Plv_min_results', ...
        'DeltaPlv_results','CO_results', 'HR_results', 'SV_results', 'PO_results');

    writetable(resultsTable, csvName);

    fprintf('Saved results for %s condition to:\n  %s\n  %s\n', condition, matName, csvName);

end

fprintf('All cuff pressure arrays saved independently to:\n  %s\n', cuffFile);


