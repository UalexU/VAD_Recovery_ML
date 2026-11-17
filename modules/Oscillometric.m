function [SBP,DBP,MAP]=Oscillometric(P_of_t,threshold, doPlot)
if nargin < 3 
    doPlot = true; % default: plot everything
end
% Extract the cuff pressure from simulation
N = length(P_of_t);
Pa = P_of_t(:,2); % Arterial Pressure Psa
Pcuff = P_of_t(:,3); % Cuff Pressure
HR = 72; % Heart Rate in beats/min
Ts = 0.002;  % step size in simulation
Tc = 60/HR;  % Cardiac period in sec/beat
D = fix(Tc/2/Ts); % Number of data point for a half heart period

% Smooth the cuff pressure using a moving average filter
Psm = zeros(N,1);
for k = D+1:N-D,
    Psm(k) = mean(Pcuff(k-D:k+D));
end;

% Truncate unnecessary data before cuff deflection and the last half of the
% cardiac period at the end
index = [ceil(11/Ts):N-D]; 
Psm = Psm(index);
Pcuff = Pcuff(index);
Pfilter = Pcuff - Psm;
t = [Ts:Ts:length(Psm)*Ts];

% Detect the min & max cuff pressure from each heart beat using the
% peakdet.m (Ref: http://billauer.co.il/peakdet.html)
[maxPf, minPf] = peakdet(Pfilter, threshold);

% Data plot of Fig.5(b) with the markers on the min & max in each beat
if doPlot
figure(1) 
plot(t,Pfilter), grid, hold on
xlabel('Time [sec]')
ylabel('Filtered Oscillation Pressure [mmHg]')
plot(t(maxPf(:,1)), maxPf(:,2), 'r*');
plot(t(minPf(:,1)), minPf(:,2), 'g*');
hold off

% Data plot of Fig. 6(a) 
figure(2)
plot(Psm, Pfilter), grid
xlabel('Smoothed Cuff Pressure [mmHg]')
ylabel('Filtered Oscillation Pressure [mmHg]')
set(gca,'xdir','reverse') % Reverse the x-axis
end
% Extract the envelope pressure and the diastolic cuff pressure 
% corresponding to each heart beat
M = min(length(minPf), length(maxPf));
index = [1:M];
PP = maxPf(index,2)-minPf(index,2); % Envelope pressure
Pc = Pcuff(minPf(index,1));

% Data plot of Fig. 6(b)
if doPlot
figure(3)
plot(Pc, PP)
grid
xlabel('Cuff Pressure [mmHg]')
ylabel('Envelope [mmHg]')
set(gca,'xdir','reverse') % Reverse the x-axis 
hold on
end
% Extract data for curve fitting in Domain 1
if isempty(PP) || length(PP) < 3
    SBP = NaN; DBP = NaN; MAP = NaN;
    return;
end

[dYmax, Imax]=max(diff(PP));
    % Instantaneous diastolic cuff pressure in Domain 1 
    Pd1 = Pc(1:Imax);
    % Pulse pressure in Domain 1
    DP1 = PP(1:Imax);
[dYmin, Imin]=min(diff(PP));
    % Instantaneous diastolic cuff pressure in Domain 3 
    Pd3 = Pc(Imin:M);
    % Pulse pressure in Domain 3
    DP3 = PP(Imin:M);

% Least squares fit to estimate the coefficients a and b
% Domain 1
if length(Pd1) > 1
    K1 = polyfit(Pd1, log(DP1), 1);
else
    K1 = [0, 0]; % Fallback if not enough points
end
DP1_hat = exp(K1(2)*ones(size(Pd1)) + K1(1)*Pd1);
E1 = DP1 - DP1_hat;
if (DP1'*DP1) > 0
    EI1 = sqrt((E1'*E1)/(DP1'*DP1))*100; %Estimation error index in percentage
else
    EI1 = 0;
end

if doPlot
% Show markers of the estimated pressure envelope in Domain 1
plot(Pd1, DP1_hat, 'k+'), hold on
end

% Domain 3
if length(Pd3) > 1
    K3 = polyfit(Pd3, log(DP3), 1);
else
    K3 = [0, 0]; % Fallback if not enough points
end
DP3_hat = exp(K3(2)*ones(size(Pd3)) + K3(1)*Pd3);
E3 = DP3 - DP3_hat;
if (DP3'*DP3) > 0
    EI3 = sqrt((E3'*E3)/(DP3'*DP3))*100; %Estimation error index in percentage
else
    EI3 = 0;
end

if doPlot
% Show markers of the estimated pressure envelope in Domain 3
plot(Pd3, DP3_hat, 'rx'), hold off
end
% Systolic and Diastolic Pressure Estimation
% Assign coefficients
a = -K1(1);  b = K3(1);

% Prevent division by zero or NaN if coefficients are invalid
if b == 0 || isnan(a) || isnan(b)
    SBP = NaN; DBP = NaN; MAP = NaN;
    return;
end

Va0 = 0.3; V0 = 300; Patm = 760;

% Define the ranges of systolic (40 to 160 mmHg) and diastolic
% (40 to 160 mmHg) pressure for estimation
SP = [40:160]; DP = [40:160];
L = length(Pc);
% Same model equations as the original per-sample loop, evaluated on whole
% vectors. Terms that don't depend on the inner loops are computed once.
X    = Va0*(Pc+Patm)/V0;
PPn  = PP/max(PP);
EA_D = zeros(L, length(DP)); EB_D = zeros(L, length(DP));
for n=1:length(DP)
    EA_D(:,n) = exp(a*(DP(n)-Pc));
    EB_D(:,n) = exp(-b*(DP(n)-Pc));
end
SS = 1000*ones(length(SP), length(DP)); % Unrealistic (DBP >= SBP) keep high error
PP_hat = zeros(L,1);
for m=1:length(SP)
    SBP = SP(m);
    EA_S = exp(a*(SBP-Pc));
    EB_S = exp(-b*(SBP-Pc));
    hi = Pc >= SBP;
    for n=1:length(DP)
        DBP = DP(n);
        if DBP < SBP % In reality, SBP > DBP
            mid = ~hi & Pc >= DBP;
            lo  = ~hi & ~mid;
            PP_hat(hi)  = X(hi).*(EA_S(hi)-EA_D(hi,n));
            PP_hat(mid) = X(mid).*(1+a/b*(1-EB_S(mid))-EA_D(mid,n));
            PP_hat(lo)  = X(lo)*a/b.*(EB_D(lo,n)-EB_S(lo));
            PP_hat_compressed=PP_hat(1:length(PP));
            ERR = PPn - PP_hat_compressed/max(PP_hat_compressed);
            SS(m,n) = ERR' * ERR;
        end
    end
end

if isempty(SS)
    SBP = NaN; DBP = NaN; MAP = NaN;
    return;
end

[Y, I]=min(min(SS)); [X, J]=min(SS(:,I));
SBP = min(SP)+J-1;
DBP = min(DP)+I-1;
MAP = 2/3*SBP + DBP/3;
end