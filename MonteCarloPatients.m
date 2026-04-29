clc; clear; close all;

%% 1. Setup Environment
addpath(genpath('modules'));

global BASENAME
BASENAME = 'modelv3/Interface/';
HeartConstantsv3;

%% 2. Monte Carlo Configuration
N_MC = 50; % Reduced to 50 for a quicker run, increase as needed

% Parameters within boundaries
emax_lo = 0.14;   emax_hi = 1.20;
rpm_lo  = 8;      rpm_hi  = 10;
al_lo   = 0.05;   al_hi   = 5.0;
pl_lo   = 0.1;    pl_hi   = 1.9;

% Fixed parameters
pump_on = 1;
threshold = 0.25;
Vuev_Gain_Factor = 1;

%% 3. Generate and Simulate Patients
rng('shuffle');
u = rand(N_MC, 4); 

% Preallocate results table structure
results_list = [];

fprintf('Starting Monte Carlo Simulation for %d patients...\n', N_MC);

for k = 1:N_MC
    % --- Set Parameters ---
    strength_factor = emax_lo + u(k,1) * (emax_hi - emax_lo);
    pump_speed      = rpm_lo  + u(k,2) * (rpm_hi  - rpm_lo);
    Rsp_Gain_Factor = al_lo   + u(k,3) * (al_hi   - al_lo);
    Rep_Gain_Factor = Rsp_Gain_Factor;
    Vusv_Gain_Factor = pl_lo   + u(k,4) * (pl_hi   - pl_lo);
    
    fprintf(' [%d/%d] Emax: %.3f, RPM: %.1f, AL: %.2f, PL: %.2f ... ', ...
        k, N_MC, strength_factor, pump_speed, Rsp_Gain_Factor, Vusv_Gain_Factor);

    % --- Run Simulation ---
    try
        sim('modelv3_1');
        
        % --- Extract Features ---
        simData = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink);
        oscData = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, Qpump, dQpump, simData.HR);
        
        % Determine Condition
        if strength_factor < 0.25
            cond = "Failure";
        elseif strength_factor < 0.6
            cond = "Recovery";
        else
            cond = "Normal";
        end
        
        % --- Store Row ---
        row = struct();
        row.ID        = sprintf('MC_%05d', k);
        row.Emax      = strength_factor;
        row.RPM       = pump_speed;
        row.Afterload = Rsp_Gain_Factor;
        row.Preload   = Vusv_Gain_Factor;
        row.Condition = cond;
        
        % Extracted Features
        row.FFT_H1    = oscData.H1;
        row.FFT_H2    = oscData.H2; 
        row.PumpFlow  = oscData.Qpump;
        row.dPumpFlow = oscData.dQpump;
        row.dQ_H1     = oscData.dQ_H1;
        row.dQ_H2     = oscData.dQ_H2;
        row.MAP       = oscData.MAP;
        row.SBP       = oscData.SBP;
        row.DBP       = oscData.DBP;
        
        results_list = [results_list; row]; %#ok<AGROW>
        fprintf('Done.\n');
        
    catch ME
        fprintf('FAILED (%s)\n', ME.message);
    end
end

%% 4. Save to CSV
if ~exist('Data', 'dir'), mkdir('Data'); end
T = struct2table(results_list);
writetable(T, 'Data/MonteCarloPatients_with_Features.csv');

fprintf('\nSuccess! Saved %d simulated patients to Data/MonteCarloPatients_with_Features.csv\n', height(T));


