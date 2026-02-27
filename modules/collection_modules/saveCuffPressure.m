function saveCuffPressure(cuffPressure, runID, strengthFactor, pumpSpeed, condition, fileType, scenario)
% saveCuffPressure  Save cuff pressure array with metadata into a scenario-specific master file.
%
%   cuffPressure   : 5000x2 array from simulation
%   runID          : integer run index
%   strengthFactor : numeric heart strength factor (e.g. 1.0, 0.3, 0.18)
%   pumpSpeed      : numeric pump speed (e.g. 8.0)
%   condition      : string label ('Normal','Recovery','Failing')
%   fileType       : 'mat' or 'csv'
%   scenario       : string label for simulation type (e.g. 'PumpOn_RPMSweep')
%
% Example:
%   saveCuffPressure(cuffPressure_log, 1, 1.0, 8.0, 'Normal', 'csv', 'PumpOn_RPMSweep');

    % Ensure Data folder exists
    savePath = 'Data';
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end

    if strcmpi(fileType, 'csv')
        % --- CSV mode ---
        masterFile = fullfile(savePath, sprintf('CuffPressure_Master_%s.csv', scenario));
        nRows = size(cuffPressure,1);

        % Build metadata columns
        meta = repmat([runID, strengthFactor, pumpSpeed], nRows, 1);
        runData = [meta cuffPressure];

        % Convert to table
        runTable = array2table(runData, ...
            'VariableNames', {'RunID','StrengthFactor','PumpSpeed','CuffPressure1','CuffPressure2'});

        % Append or create
        if isfile(masterFile)
            writetable(runTable, masterFile, 'WriteMode','append');
        else
            writetable(runTable, masterFile);
        end

        fprintf('Appended cuff pressure data to %s\n', masterFile);

    elseif strcmpi(fileType, 'mat')
        % --- MAT mode ---
        masterFile = fullfile(savePath, sprintf('CuffPressure_Master_%s.mat', scenario));
        runStruct.RunID = runID;
        runStruct.StrengthFactor = strengthFactor;
        runStruct.PumpSpeed = pumpSpeed;
        runStruct.Condition = condition;
        runStruct.CuffPressure = cuffPressure;

        % Append to cell array
        if isfile(masterFile)
            load(masterFile, 'allRuns');
            allRuns{end+1} = runStruct;
        else
            allRuns = {runStruct};
        end

        save(masterFile, 'allRuns');
        fprintf('Appended cuff pressure struct to %s\n', masterFile);

    else
        error('fileType must be ''csv'' or ''mat''.');
    end
end
