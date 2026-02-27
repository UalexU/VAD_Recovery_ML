function [maxPeakValue, maxPeakIndex, maxPeakTime, minPeakValue, minPeakIndex, minPeakTime] = getPeakInfo(data)
    signal = data(:, 2);                  % Extract signal column
    [maxPeakValue, maxPeakIndex] = max(signal); % Find max value and its index
    [minPeakValue, minPeakIndex] = min(signal); % Find min value and its index
   % Get corresponding timestamp
    maxPeakTime = data(maxPeakIndex, 1);       
    minPeakTime = data(minPeakIndex, 1);
end