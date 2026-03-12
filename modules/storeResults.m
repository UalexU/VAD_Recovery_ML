function R = storeResults(R, S, O, pump_speed, k, afterload, preload)

R.RPM(k)       = pump_speed;
if nargin >= 6, R.Afterload(k) = afterload; end
if nargin >= 7, R.Preload(k)   = preload;   end

R.SBP(k)       = O.SBP;
R.DBP(k)       = O.DBP;
R.MAP(k)       = O.MAP;
R.DeltaPsa(k)  = O.DeltaPsa;

R.Psa_mean(k)  = mean(O.Psa(:,2));
R.Plv_mean(k)  = mean(O.Plv(:,2));

R.Psa_max(k)   = O.Psa_max;
R.Prv_max(k)   = O.Prv_max;
R.Plv_max(k)   = O.Plv_max;
R.Plv_min(k)   = O.Plv_min;
R.DeltaPlv(k)  = O.DeltaPlv;

R.FirstFFT(k)  = O.H1;
R.SecondFFT(k) = O.H2;

% Additional pump and pressure features
R.PumpPressure_mean(k) = R.Psa_mean(k) - R.Plv_mean(k);
pumpP_signal = O.Psa(:,2) - O.Plv(:,2);
R.DeltaPumpPressure(k) = max(pumpP_signal) - min(pumpP_signal);
R.DeltaP(k)        = max(O.Psa(:,2)) - min(O.Psa(:,2)); % Psa Pulse Pressure

% Updated Pump Flow features (now using cycle-averaged peak-to-peak)
R.PumpFlow(k) = O.Qpump;
R.dPumpFlow(k) = O.dQpump;

R.CO(k)        = S.CO;
R.HR(k)        = S.HR;
R.SV(k)        = S.SV;
R.PO(k)        = S.PO;

end
