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
% I need to introduce a % error into P so I have some sensor noise that can
% back propagate
[O.SBP, O.DBP, O.MAP] = Oscillometric(P, 0.02, false);
O.DeltaPsa = O.SBP - O.DBP;

O.DeltaPlv = O.Plv_max - O.Plv_min;

% --- Pump Flow Analysis (trimmed to last N complete cycles) ---
num_cycles = 5;

% Handle Qpump as either matrix or timeseries
if isa(Qpump, 'timeseries')
    Q_full = Qpump.Data;
    time_full = Qpump.Time;
    Ts_Q = time_full(2) - time_full(1);
else
    Q_full = Qpump(:, 2);
    Ts_Q = Qpump(2,1) - Qpump(1,1);
end

N_Q = length(Q_full);

if nargin >= 8 && ~isempty(HR) && HR > 0
    T_beat = 60 / HR;
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

% --- Calculate dQ/dt numerically from Q_trim ---
% dQ/dt = (Q(k) - Q(k-1)) / Ts
dQ_numeric = [0; diff(Q_trim)] ./ Ts_Q;

% --- Apply 3rd Order Butterworth Low-Pass Filter (20Hz) ---
fc = 20; % Cut-off frequency (Hz)
fs = 1 / Ts_Q; % Sampling frequency (Hz)
[b, a] = butter(3, fc / (fs/2), 'low'); % Normalized frequency

% Use filtfilt for zero-phase distortion
dQ_filtered = filtfilt(b, a, dQ_numeric);

% Use this new filtered signal for pulsatility analysis
dQ_trim = dQ_filtered;


% O.Qpump = Q_full;
% O.Qpump_mean = mean(Q_trim); % Cycle-accurate mean

% I need to introduce a % error into Qpump so I have some sensor noise that can
% back propagate

% For dQpump we need to add the noise into the Qpump and then pass it on a
% the dQdt. This data will need to be fed ton a low pass filter max 3er
% order, and 20Hz cut. prof. yu mentioned to try filtfilt? 

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
% Increased threshold slightly as derivative noise might be higher
[maxtab_dQ, mintab_dQ] = peakdet(dQ_trim, 1.0);
if ~isempty(maxtab_dQ) && ~isempty(mintab_dQ)
    O.dQpump = mean(maxtab_dQ(:, 2)) - mean(mintab_dQ(:, 2));
else
    O.dQpump = max(dQ_trim) - min(dQ_trim);
end

% --- FFT on trimmed dQ/dt signal ---
% dQ_trim length differs from P_all.Time
time_dQ = (0:length(dQ_trim)-1)' * Ts_Q;
[O.dQ_H1, O.dQ_H2] = getFFT(dQ_trim, time_dQ, false);

end