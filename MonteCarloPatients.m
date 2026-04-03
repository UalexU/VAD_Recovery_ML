
clc; clear; close all;

% This generates patients all across the cardiac functions
% However, for classification purposes defining a more clear 

% Number of Monte Carlo samples 
N_MC = 100;
% Parameters within the boundary
emax_lo = 0.14;   emax_hi = 1.20;
rpm_lo  = 8;      rpm_hi  = 10;
al_lo   = 0.05;   al_hi   = 5.0;
pl_lo   = 0.1;    pl_hi   = 1.9;

% Generate Monte Carlo samples
u = rand(N_MC, 4); % random numbers between 0 and 1, 4 columns for emax, rpm, al, pl
jobs = struct('Emax', {}, 'RPM', {}, 'AL', {}, 'PL', {}, 'ID', {});
for k = 1:N_MC
    % minimum + random number between 0 and 1 * (maximum - minimum)
    new_job.Emax = emax_lo + u(k,1) * (emax_hi - emax_lo);
    new_job.RPM  = rpm_lo  + u(k,2) * (rpm_hi  - rpm_lo);
    new_job.AL   = al_lo   + u(k,3) * (al_hi   - al_lo);
    new_job.PL   = pl_lo   + u(k,4) * (pl_hi   - pl_lo);
    new_job.ID   = sprintf('MC_%07d', k); % Max 7 index digits
    jobs(end+1) = new_job; 
end

% Save patients to CSV
writetable(struct2table(jobs), 'Data/MonteCarloPatients.csv');


