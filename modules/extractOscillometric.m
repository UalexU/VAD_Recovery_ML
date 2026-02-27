function O = extractOscillometric(P, P_all, Psa_log, Prv_log, Plv_log, Qpump, dQpump, HR)
% extractOscillometric - Extracts oscillometric, FFT, and pump features
%
% The optional HR argument (beats/min) is used to trim ONLY pump flow
% signals (Qpump, dQpump) to the last N complete cardiac cycles before
% averaging. All other features use the full logged signal (original).

Pressure = P_all.Data;
timeVec = P_all.Time;
Pcuff   = Pressure(:,3);

% FFT on full cuff pressure (original behavior)
[O.H1, O.H2] = getFFT(Pcuff, timeVec, false);

% Pressure peaks
[O.Psa_max] = getPeakInfo(Psa_log);
[O.Prv_max] = getPeakInfo(Prv_log);
[O.Plv_max, ~, O.Plv_min] = getPeakInfo(Plv_log);

O.Psa = Psa_log;
O.Plv = Plv_log;
[O.SBP, O.DBP, O.MAP] = Oscillometric(P, 0.02, false);
O.DeltaPsa = O.SBP - O.DBP;

O.DeltaPlv = O.Plv_max - O.Plv_min;

% --- Pump Flow Analysis (trimmed to last N complete cycles) ---
num_cycles = 5;
Q_full  = Qpump(:, 2);
dQ_full = dQpump(:, 2);
% I need to do the delta max - min. 
N_Q = length(Q_full);
if nargin >= 8 && ~isempty(HR) && HR > 0
    T_beat = 60 / HR;
    Ts_Q = Qpump(2,1) - Qpump(1,1); % Time step from column 1
    samples_Q = round(T_beat / Ts_Q) * num_cycles; % number of samples in the last N complete cycles 
    if samples_Q < N_Q
        q_start = N_Q - samples_Q + 1; % start index of the last N complete cycles
    else
        q_start = 1;
    end
else
    q_start = 1; % No HR provided, use full signal
end

Q_trim  = Q_full(q_start:end);
dQ_trim = dQ_full(q_start:end);

% O.Qpump = Q_full;
% O.Qpump_mean = mean(Q_trim); % Cycle-accurate mean

% Find peaks of Qpump and average them for mean_max
[maxtab_Q, mintab_Q] = peakdet(Q_trim, 0.5);
if ~isempty(maxtab_Q) && ~isempty(mintab_Q)
    O.Qpump = mean(maxtab_Q(:, 2)) - mean(mintab_Q(:, 2));
else
    O.Qpump = max(Q_trim) - min(Q_trim);
end

% Pump Flow Differential Analysis
% O.dQpump = dQ_full;
% O.dQpump_mean = mean(dQ_trim); % Cycle-accurate mean

% Find peaks of dQpump and average them for mean_max
[maxtab_dQ, mintab_dQ] = peakdet(dQ_trim, 1.0);
if ~isempty(maxtab_dQ) && ~isempty(mintab_dQ)
    O.dQpump = mean(maxtab_dQ(:, 2)) - mean(mintab_dQ(:, 2));
else
    O.dQpump = max(dQ_trim) - min(dQ_trim);
end

end
