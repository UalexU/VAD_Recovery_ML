function R = initResultStruct(n, strength_factor)

R.Emax      = strength_factor * ones(n,1);
R.RPM       = zeros(n,1);

R.SBP       = zeros(n,1);
R.DBP       = zeros(n,1);
R.MAP       = zeros(n,1);
R.DeltaPsa  = zeros(n,1);

R.Psa_mean  = zeros(n,1);
R.Plv_mean  = zeros(n,1);
R.Psa_max   = zeros(n,1);
R.Prv_max   = zeros(n,1);
R.Plv_max   = zeros(n,1);
R.Plv_min   = zeros(n,1);
R.DeltaPlv  = zeros(n,1);

R.DeltaP  = zeros(n,1);

% Updated Pump Features
R.PumpFlow = zeros(n,1);      % Pulsatility (max-min)
R.dPumpFlow = zeros(n,1);     % Derivative pulsatility (max-min)
R.DeltaPumpPressure = zeros(n,1);
R.PumpPressure_mean  = zeros(n,1);

R.FirstFFT  = zeros(n,1);
R.SecondFFT = zeros(n,1);

R.CO        = zeros(n,1);
R.HR        = zeros(n,1);
R.SV        = zeros(n,1);
R.PO        = zeros(n,1);

end
