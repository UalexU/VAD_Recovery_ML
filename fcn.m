
function [LVPed,Psa_sys,Psa_dia,Psa_mean,Pla_mean] = fcn(Plv,Psa,Pla)
LVPed = min(Plv);
Psa_sys=max(Psa);
Psa_dia=min(Psa);
LVPed = LVPed(1,2);
Psa_sys=Psa_sys(1,2);
Psa_dia=Psa_dia(1,2);
Psa_mean=Psa_sys/3 + 2*Psa_dia/3;
end


