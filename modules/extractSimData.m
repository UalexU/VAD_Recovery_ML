function S = extractSimData(CO_sim, HR_sim, SV_sim, PO_sim, Psa_mean_from_simulink)

S.CO = CO_sim(end);
S.HR = HR_sim(end);
S.SV = SV_sim(end);
S.PO = PO_sim(end);

S.Psa_mean = Psa_mean_from_simulink(end);

end
