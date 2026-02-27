function R = storeResults(R, S, O, pump_speed, k)

R.RPM(k)       = pump_speed;

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
R.DeltaPumpPressure(k) = max(O.Qpump) - min(O.Qpump); 
R.DeltaP(k)        = max(O.Psa(:,2)) - min(O.Psa(:,2)); % Psa Pulse Pressure
R.PumpFlow_mean(k) = O.Qpump_mean;
R.PumpFlow_mean_max(k) = O.Qpump_mean_max;
R.dPumpFlow(k)     = O.dQpump_mean;
R.dPumpFlow_mean_max(k) = O.dQpump_mean_max;

R.CO(k)        = S.CO;
R.HR(k)        = S.HR;
R.SV(k)        = S.SV;
R.PO(k)        = S.PO;

end
