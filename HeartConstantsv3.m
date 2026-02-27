% HeartConstants.m
% File of constants for use in heart model

% clc;clear all;

global BASENAME
BASENAME = 'modelv3/Interface/';


%%%%%%%%%%%%%%%%%%% THE HEART AS A PUMP %%%%%%%%%%%%%%%%%%%%%

% phi generator
Tsys0 = 0.5; % s
ksys = 0.075; % s^2

% Parameters describing the left heart
Cla = 19.23; % ml/mmHg
Vula = 25; % ml
Rla = 2.5e-3; % mmHg*s*ml^-1
P0lv = 1.5; % mmHg
kElv = 0.014; % ml^-1
Vulv = 16.77; % ml
kRlv = 3.75e-4; % s/ml

% Parameters to simulate cardiac functions
Emaxlv =2.95;%Heart Normal
%Use strength factors listed below to set the strength_factor_left in the
%simulink interface
%1 Normal Heart, 0.3 Recovery Heart, 0.18 Failure Heart
% We multiply these variables to Emax to define our heart condition

% Parameters describing the right heart
Cra = 31.25; % ml/mmHg
Vura = 25; % ml
Rra = 2.5e-3; % mmHg*s*ml^-1
P0rv = 1.5; % mmHg
kErv = 0.011; % ml^-1
Vurv = 40.8; % ml
Emaxrv = 1.75; % mmHg/ml
kRrv = 1.4e-3; % s/ml


%%%%%%%%%% THE VASCULAR SYSTEM IN BASAL CONDITION %%%%%%%%%

% compliances
Csa = 0.28; % ml/mmHg
Csp = 2.05;
Cep = 1.67;
Csv = 61.11;
Cev = 50.0;
Cpa = 0.76;
Cpp = 5.80;
Cpv = 25.37; %This is capacitor. Flunctuations makes things don't change much. 

% Unstressed volumes
Vusa = 0; % ml
Vusp = 274.4;
Vuep = 336.6;
Vusv = 1121;
Vuev = 1375;
Vupa = 0;
Vupp = 123;
Vupv = 120;
Vt0 = 5100;

% equation 10
Vu = Vusa + Vusp + Vuep + Vusv + Vuev + Vura + Vupa + Vupp + Vupv + Vula;

% hydraulic resistances
Rsa = 0.06; % mmHg*s*ml^-1
Rsp = 3.307;
Rep = 1.407;
Rsv = 0.038;
Rev = 0.016;
Rpa = 0.023;
Rpp = 0.0894;
Rpv = 0.0056;


% intertances
Lsa = 0.22e-3; % mmHg*ml*s^-2
Lpa = 0.18e-3;

% 
% % addition: vena cava
% Rvc = 0.0054; % mmHg*s/ml
% Cvc = 33; % ml/mmHg
% % new values for Csv and Cev
% Csv = 43.11; % ml/mmHg
% Cev = 35; % ml/mmHg
% % special parameters that apply when stressed Vvc < 0
% D2 = -0.1616;
% K2 = 0.1616;
% Vmin = 50;

%%%%%%%%% CAROTID BAROREFLEX CONTROL SYSTEM %%%%%%%%%%%%%%%%

% Carotid sinus afferent pathway (eqs. 30-31)
Pn = 92; % mmHg
ka = 11.758; % mmHg
fmin = 2.52; % spikes/sec
Tz = 6.37; % sec
fmax = 47.78; % spikes/sec
Tp = 2.076; % sec

% Sympathetic efferent pathway (eq. 33)
fesinf = 2.10; % spikes/sec
fes0 = 16.11; % spikes/sec
fesmin = 2.66; % spikes/sec
kes = 0.0675; % sec

% Vagal efferent pathway (eq. 34)
fev0 = 3.2; % spikes/sec
fevinf = 6.3; % spikes/sec
fcs0 = 25; % spikes/sec
kev = 7.06; % spikes/sec

% Effectors (eqs. 35-42)
GEmaxlv = 0.475; % mmHg/ml/v
GEmaxrv = 0.282; % mmHg/ml/v
GRsp = 0.695; % mmHg*s/ml/v
GRep = 0.53; % mmHg*s/ml/v
GVusv = -265.4; % ml/v
GVuev = -132.5; % ml/v
GTs = -0.13; % s/v
GTv = 0.09; % s/v

TEmaxlv = 8; % sec
TEmaxrv = 8; % sec
TRsp = 6; % sec
TRep = 6; % sec
TVusv = 20; % sec
TVuev = 20; % sec
TTs = 2; % sec
TTv = 1.5; % sec

DEmaxlv = 2; % sec
DEmaxrv = 2; % sec
DRsp = 2; % sec
DRep = 2; % sec
DVusv = 5; % sec
DVuev = 5; % sec
DTs = 2; % sec
DTv = 0.2; % sec

Emaxlv0 = 2.392; % mmHg/ml
Emaxrv0 = 1.412; % mmHg/ml
Rsp0 = 2.49; % mmHg*s/ml
Rep0 = 0.78; % mmHg*s/ml
Vusv0 = 1435.4; % ml
Vuev0 = 1537; % ml
T0 = 0.58; % sec

%for cuff params
Po = 150;
r = 3;
a = 0.11;
Vao = 0.3;
b = 0.03;
V = 300;
Patm = 760;
Pth=0;