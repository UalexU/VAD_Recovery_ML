%Authored by Alex Villalba (15/1/2026), based on newfilterapproach model from Tafita Rakotozandry (1/21/2022)
%Title: FFT filter function
%Description: This program extracts the cuff pressure from the Ursion's
%model and makes of the fft the algorithm to extract the first harmonic
%peak

function [H1_mag, H2_mag, H1_freq, H2_freq] = getFFT(Pcuff, timeVec, use_max)
% getFFT
% -------------------------------------------------------------------------
% Extracts first and second harmonic peaks from cuff pressure signals.
% Inputs:
%   Pcuff    - Cuff pressure signal
%   timeVec  - Time vector
%   use_max  - TRUE: use max() for peaks (Normal)
%              FALSE: use peakdet() for peaks
% -------------------------------------------------------------------------

    % --- Sampling Configuration ---
    Ts = timeVec(2) - timeVec(1);
    fs = 1 / Ts; 

    %% Band pass filtering and FFT calculation
    Pfilter = bandpass(Pcuff, [.5, 20], fs); % band pass filter

    N = length(Pfilter);           
    X_mags = abs(fft(Pfilter)/N*2); 
    bin_vals = [0 : N-1];          
    feq_Hz = bin_vals*fs/N;        
    N_2 = ceil(N/2);               

    x = feq_Hz(1:N_2)';             % frequency coordinate (column vector)
    y = X_mags(1:N_2);             % amplitude coordinate

    %% Harmonic Calculation
    if nargin < 3 || use_max
        % --- Method 1: Global Maximum (Normal) ---
        H1_mag = max(y);
        idx = find(y == H1_mag, 1);
        H1_freq = x(idx);
    else
        % --- Method 2: Peak Detection (Refined) ---
        % Use peakdet to find local maxima in the FFT spectrum
        [maxtab, ~] = peakdet(y, 0.05, x); % Delta of 0.05 magnitude
        if ~isempty(maxtab)
            % Sort by magnitude descending
            maxtab = sortrows(maxtab, -2);
            H1_freq = maxtab(1,1);
            H1_mag  = maxtab(1,2);
        else
            H1_mag = max(y);
            H1_freq = x(find(y == H1_mag, 1));
        end
    end

    % --- Second Harmonic Calculation (Windowed) ---
    window = 0.5; 
    idx2 = (x >= (2*H1_freq)-window) & (x <= (2*H1_freq)+window);
    indices = find(idx2);
    
    if ~isempty(indices)
        if nargin < 3 || use_max
            H2_mag = max(y(indices));
            idx_h2 = find(y(indices) == H2_mag, 1);
            H2_freq_cands = x(indices);
            H2_freq = H2_freq_cands(idx_h2);
        else
            % Peakdet within the window for H2
            y_win = y(indices);
            x_win = x(indices);
            [maxtab_win, ~] = peakdet(y_win, 0.01, x_win);
            if ~isempty(maxtab_win)
                % Pick highest peak in window
                maxtab_win = sortrows(maxtab_win, -2);
                H2_freq = maxtab_win(1,1);
                H2_mag  = maxtab_win(1,2);
            else
                H2_mag = max(y_win);
                H2_freq = x_win(find(y_win == H2_mag, 1));
            end
        end
    else
        H2_mag = NaN;
        H2_freq = NaN;
    end

end
