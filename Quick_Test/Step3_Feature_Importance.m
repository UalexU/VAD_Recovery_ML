%% ============================================================
%   QUICK TEST: Feature Importance Analysis
%   Shows which features contribute most to classification.
%   Run AFTER Step2_Train_Test_ML.m
% ============================================================

clc; close all;

%% Setup Folders
% Analyze locally by default.
SHARED_DRIVE_PATH = ''; 

if isempty(SHARED_DRIVE_PATH)
    base_folder = fullfile('..', 'Data', 'Quick_Test');
else
    base_folder = fullfile(SHARED_DRIVE_PATH, 'Quick_Test');
end

%% Load Dataset
csv_file = fullfile(base_folder, 'QuickTest_Database.csv');
if ~isfile(csv_file)
    error('Dataset not found at %s.', csv_file);
end
T = readtable(csv_file);

target = T.Condition;
X = [T.FFT_H1, T.FFT_H2, T.PumpFlow, T.dPumpFlow, T.MAP, T.SBP, T.DBP];
feature_labels = {'FFT H1', 'FFT H2', 'PumpFlow', 'dPumpFlow', 'MAP', 'SBP', 'DBP'};

% Local output folder for figures
local_fig_folder = fullfile('..', 'Data', 'Quick_Test', 'Figures');
if ~exist(local_fig_folder, 'dir'), mkdir(local_fig_folder); end

%% ============================================================
%   Feature Importance via Decision Tree
% ============================================================
mdl = fitctree(X, target, 'PredictorNames', feature_labels);
imp = predictorImportance(mdl);

figure('Name', 'Feature Importance', 'Color', 'w', 'Position', [100 100 700 400]);
bar(imp, 'FaceColor', [0.2 0.6 0.8]);
set(gca, 'XTickLabel', feature_labels, 'XTickLabelRotation', 45);
ylabel('Importance Score');
title('Feature Importance (Decision Tree)');
grid on;

saveas(gcf, fullfile(local_fig_folder, 'Feature_Importance.png'));

%% ============================================================
%   Leave-One-Feature-Out Analysis
%   Train KNN with ALL features, then remove one at a time
% ============================================================

fprintf('\n--- Leave-One-Feature-Out Analysis ---\n');
rng(42);
cv = cvpartition(target, 'HoldOut', 0.3);

% Baseline: all features
mdl_all = fitcknn(X(cv.training,:), target(cv.training), 'NumNeighbors', 5, 'Standardize', true);
Y_pred_all = predict(mdl_all, X(cv.test,:));
acc_all = mean(Y_pred_all == target(cv.test)) * 100;
fprintf('  All features: %.1f%%\n', acc_all);

drop_results = zeros(1, length(feature_labels));

for f = 1:length(feature_labels)
    % Remove feature f
    X_reduced = X;
    X_reduced(:, f) = [];

    mdl_reduced = fitcknn(X_reduced(cv.training,:), target(cv.training), ...
        'NumNeighbors', 5, 'Standardize', true);
    Y_pred_reduced = predict(mdl_reduced, X_reduced(cv.test,:));
    acc_reduced = mean(Y_pred_reduced == target(cv.test)) * 100;

    drop_results(f) = acc_all - acc_reduced;
    fprintf('  Without %-10s: %.1f%% (drop: %+.1f%%)\n', ...
        feature_labels{f}, acc_reduced, -drop_results(f));
end

figure('Name', 'Accuracy Drop Without Feature', 'Color', 'w', 'Position', [100 550 700 400]);
bar(drop_results, 'FaceColor', [0.8 0.3 0.3]);
set(gca, 'XTickLabel', feature_labels, 'XTickLabelRotation', 45);
ylabel('Accuracy Drop (%)');
title('Accuracy Drop When Removing Each Feature');
grid on;

saveas(gcf, fullfile(local_fig_folder, 'Feature_Drop_Analysis.png'));
fprintf('\nFigures saved locally to: %s\n', local_fig_folder);
