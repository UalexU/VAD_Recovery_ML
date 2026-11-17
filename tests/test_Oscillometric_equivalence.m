function test_Oscillometric_equivalence(resultFiles)
% Checks that the optimized Oscillometric.m returns exactly the same
% SBP/DBP/MAP as the original loop version (kept below as a reference).
%   test_Oscillometric_equivalence                 % synthetic cuff signals
%   test_Oscillometric_equivalence({'Result_X.mat'}) % saved simulation results
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'modules'));

if nargin == 0
    rng(1);
    resultFiles = num2cell(1:5);
end

for i = 1:numel(resultFiles)
    if ischar(resultFiles{i})
        d = load(resultFiles{i}, 'Signals');
        P = d.Signals.P;
    else
        P = syntheticCuff();
    end
    [s1, d1, m1] = Oscillometric(P, 0.02, false);
    [s0, d0, m0] = Oscillometric_reference(P, 0.02);
    assert(isequaln([s1 d1 m1], [s0 d0 m0]), ...
        'Mismatch on case %d: new [%g %g %g] vs ref [%g %g %g]', i, s1, d1, m1, s0, d0, m0);
end
fprintf('Oscillometric equivalence: %d/%d cases identical.\n', numel(resultFiles), numel(resultFiles));
end

function P = syntheticCuff()
% Deflating cuff with a beat-synchronous oscillation envelope (columns: t, Psa, Pcuff).
Ts = 0.002; t = (0:Ts:50)';
sbp = 100 + 30*rand; dbp = 55 + 20*rand; map = dbp + (sbp-dbp)/3;
Pc  = 180 - 3.2*max(t-10, 0);
env = 2.5*exp(-((Pc-map)/(15+10*rand)).^2);
Pcuff = Pc + env.*sin(2*pi*1.2*t) + 0.001*randn(size(t));
P = [t, dbp + (sbp-dbp)*(0.5+0.5*sin(2*pi*1.2*t)), Pcuff];
end

function [SBP,DBP,MAP]=Oscillometric_reference(P_of_t,threshold)
% Original implementation (pre-optimization), plotting removed.
N = length(P_of_t); Pcuff = P_of_t(:,3);
HR = 72; Ts = 0.002; Tc = 60/HR; D = fix(Tc/2/Ts);
Psm = zeros(N,1);
for k = D+1:N-D, Psm(k) = mean(Pcuff(k-D:k+D)); end
index = [ceil(11/Ts):N-D]; Psm = Psm(index); Pcuff = Pcuff(index);
Pfilter = Pcuff - Psm;
[maxPf, minPf] = peakdet(Pfilter, threshold);
M = min(length(minPf), length(maxPf)); index = [1:M];
PP = maxPf(index,2)-minPf(index,2); Pc = Pcuff(minPf(index,1));
if isempty(PP) || length(PP) < 3, SBP = NaN; DBP = NaN; MAP = NaN; return; end
[~, Imax]=max(diff(PP)); Pd1 = Pc(1:Imax); DP1 = PP(1:Imax);
[~, Imin]=min(diff(PP)); Pd3 = Pc(Imin:M); DP3 = PP(Imin:M);
if length(Pd1) > 1, K1 = polyfit(Pd1, log(DP1), 1); else, K1 = [0, 0]; end
if length(Pd3) > 1, K3 = polyfit(Pd3, log(DP3), 1); else, K3 = [0, 0]; end
a = -K1(1);  b = K3(1);
if b == 0 || isnan(a) || isnan(b), SBP = NaN; DBP = NaN; MAP = NaN; return; end
Va0 = 0.3; V0 = 300; Patm = 760;
SP = [40:160]; DP = [40:160]; L = length(Pc);
for m=1:length(SP)
    SBP = SP(m);
    for n=1:length(DP)
        DBP = DP(n);
        if DBP < SBP
            for k=1:L
                X = Va0*(Pc(k)+Patm)/V0;
                if Pc(k) >= SBP
                    PP_hat(k,1)=X*(exp(a*(SBP-Pc(k)))-exp(a*(DBP-Pc(k))));
                elseif Pc(k)<SBP && Pc(k)>=DBP
                    PP_hat(k,1)=X*(1+a/b*(1-exp(-b*(SBP-Pc(k))))-exp(a*(DBP-Pc(k))));
                else
                    PP_hat(k,1)=X*a/b*(exp(-b*(DBP-Pc(k)))-exp(-b*(SBP-Pc(k))));
                end
            end
            PP_hat_compressed=PP_hat(1:length(PP));
            ERR = PP/max(PP) - PP_hat_compressed/max(PP_hat_compressed);
            SS(m,n) = ERR' * ERR;
        else
            SS(m,n) = 1000;
        end
    end
end
[~, I]=min(min(SS)); [~, J]=min(SS(:,I));
SBP = min(SP)+J-1; DBP = min(DP)+I-1; MAP = 2/3*SBP + DBP/3;
end
