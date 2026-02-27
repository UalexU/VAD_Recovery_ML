function saveSweepResults(R, strength_factor, pump_speed, scenario)

condition = getConditionLabel(strength_factor);
pumpState = "PumpOn";

savePath = 'Data/Sweep/RPM/';
if ~exist(savePath, 'dir'), mkdir(savePath); end

matName = sprintf('%sSweep_RPM_Extended%s_%s_%s.mat', ...
    savePath, condition, pumpState, num2str(pump_speed));

csvName = sprintf('%sSweep_RPM_Extended%s_%s_%s.csv', ...
    savePath, condition, pumpState, num2str(pump_speed));

resultsTable = struct2table(R);

save(matName, '-struct', 'R');
writetable(resultsTable, csvName);

fprintf('Saved results for %s:\n  %s\n  %s\n', condition, matName, csvName);

end
