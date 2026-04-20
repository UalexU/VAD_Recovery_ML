function outTable = Convert_LH_Condition_To_Text(inputCsv, outputCsv, conditionColumn)
% Convert_LH_Condition_To_Text
% Replaces numeric LH condition labels with readable text labels.
%
% Mapping:
%   0 -> "Failure"
%   1 -> "Recovery"
%   2 -> "Normal"
%
% Usage examples:
%   Convert_LH_Condition_To_Text;
%   Convert_LH_Condition_To_Text('path\to\ML_Master_Database_LH.csv');
%   Convert_LH_Condition_To_Text('in.csv', 'out.csv', 'Condition');
%
% Inputs (all optional):
%   inputCsv        - Path to source CSV
%   outputCsv       - Path to output CSV
%   conditionColumn - Column name containing 0/1/2 labels
%
% Output:
%   outTable        - Converted table (also written to outputCsv)

    if nargin < 1 || isempty(inputCsv)
        inputCsv = fullfile('..', 'Data', 'ML_Database_LH', 'ML_Master_Database_LH.csv');
    end

    if nargin < 2 || isempty(outputCsv)
        [folderPath, baseName, ext] = fileparts(inputCsv);
        outputCsv = fullfile(folderPath, [baseName '_text_labels' ext]);
    end

    if nargin < 3 || isempty(conditionColumn)
        conditionColumn = 'Condition';
    end

    if ~isfile(inputCsv)
        error('Input CSV not found: %s', inputCsv);
    end

    T = readtable(inputCsv);

    if ~ismember(conditionColumn, T.Properties.VariableNames)
        error('Column "%s" was not found in %s', conditionColumn, inputCsv);
    end

    rawVals = T.(conditionColumn);
    numericVals = normalizeToNumeric(rawVals, conditionColumn);

    textLabels = strings(height(T), 1);
    textLabels(numericVals == 0) = "Failure";
    textLabels(numericVals == 1) = "Recovery";
    textLabels(numericVals == 2) = "Normal";

    unknownMask = ~(numericVals == 0 | numericVals == 1 | numericVals == 2);
    if any(unknownMask)
        warning('%d rows in "%s" were not 0/1/2. They are set to "Unknown".', ...
                sum(unknownMask), conditionColumn);
        textLabels(unknownMask) = "Unknown";
    end

    T.(conditionColumn) = textLabels;
    outTable = T;

    writetable(outTable, outputCsv);
    fprintf('Converted labels saved to:\n  %s\n', outputCsv);
end

function numericVals = normalizeToNumeric(rawVals, conditionColumn)
% Converts several possible table column types to numeric for mapping.
    if isnumeric(rawVals) || islogical(rawVals)
        numericVals = double(rawVals);
        return;
    end

    if isstring(rawVals) || ischar(rawVals)
        numericVals = str2double(string(rawVals));
        return;
    end

    if iscellstr(rawVals) || iscell(rawVals)
        numericVals = str2double(string(rawVals));
        return;
    end

    if iscategorical(rawVals)
        numericVals = str2double(string(rawVals));
        return;
    end

    error('Unsupported data type in "%s" column: %s', conditionColumn, class(rawVals));
end
