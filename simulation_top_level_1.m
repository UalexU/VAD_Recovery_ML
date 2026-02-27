clear all; 
global BASENAME
BASENAME = 'modelv3/Interface/';
run('HeartConstantsv3.m');
pump_on=0;
pump_speed=8;
threshold=0.25;

% Case (1)
strength_factor=0.18;
sim('modelv3_1');
[LVPed,Psa_sys,Psa_dia,Psa_mean] = fcn(Plv,Psa);
[SBP,DBP,MAP]=Oscillometric(P,threshold);
CO=CO_sim(length(CO_sim),1);
HR=HR_sim(length(HR_sim),1);
SV=SV_sim(length(SV_sim),1);
PO=PO_sim(length(PO_sim),1);
Result1 = table(LVPed,Psa_mean,Psa_sys,Psa_dia,SBP,DBP,MAP,CO,HR,SV,PO);

% Case (2)
strength_factor=0.24;
sim('modelv3_1');
[LVPed,Psa_sys,Psa_dia,Psa_mean] = fcn(Plv,Psa);
[SBP,DBP,MAP]=Oscillometric(P,threshold);
CO=CO_sim(length(CO_sim),1);
HR=HR_sim(length(HR_sim),1);
SV=SV_sim(length(SV_sim),1);
PO=PO_sim(length(PO_sim),1);
Result2 = table(LVPed,Psa_mean,Psa_sys,Psa_dia,SBP,DBP,MAP,CO,HR,SV,PO);

% Case (3)
strength_factor=0.3;
sim('modelv3_1');
[LVPed,Psa_sys,Psa_dia,Psa_mean] = fcn(Plv,Psa);
[SBP,DBP,MAP]=Oscillometric(P,threshold);
CO=CO_sim(length(CO_sim),1);
HR=HR_sim(length(HR_sim),1);
SV=SV_sim(length(SV_sim),1);
PO=PO_sim(length(PO_sim),1);
Result3 = table(LVPed,Psa_mean,Psa_sys,Psa_dia,SBP,DBP,MAP,CO,HR,SV,PO);

% Case (4)
strength_factor=0.5;
sim('modelv3_1');
[LVPed,Psa_sys,Psa_dia,Psa_mean] = fcn(Plv,Psa);
[SBP,DBP,MAP]=Oscillometric(P,threshold);
CO=CO_sim(length(CO_sim),1);
HR=HR_sim(length(HR_sim),1);
SV=SV_sim(length(SV_sim),1);
PO=PO_sim(length(PO_sim),1);
Result4 = table(LVPed,Psa_mean,Psa_sys,Psa_dia,SBP,DBP,MAP,CO,HR,SV,PO);

% Case (5)
strength_factor=0.75;
sim('modelv3_1');
[LVPed,Psa_sys,Psa_dia,Psa_mean] = fcn(Plv,Psa);
[SBP,DBP,MAP]=Oscillometric(P,threshold);
CO=CO_sim(length(CO_sim),1);
HR=HR_sim(length(HR_sim),1);
SV=SV_sim(length(SV_sim),1);
PO=PO_sim(length(PO_sim),1);
Result5 = table(LVPed,Psa_mean,Psa_sys,Psa_dia,SBP,DBP,MAP,CO,HR,SV,PO);

% Case (6)
strength_factor=1;
sim('modelv3_1');
[LVPed,Psa_sys,Psa_dia,Psa_mean] = fcn(Plv,Psa);
[SBP,DBP,MAP]=Oscillometric(P,threshold);
CO=CO_sim(length(CO_sim),1);
HR=HR_sim(length(HR_sim),1);
SV=SV_sim(length(SV_sim),1);
PO=PO_sim(length(PO_sim),1);
Result6 = table(LVPed,Psa_mean,Psa_sys,Psa_dia,SBP,DBP,MAP,CO,HR,SV,PO);
