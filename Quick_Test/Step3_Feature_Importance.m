%% ============================================================
%   QUICK TEST: Feature Importance Analysis
%   Shows which features contribute most to classification.
%   Run AFTER Step2_Train_Test_ML.m
% ============================================================

clc; close all;

%% Load Dataset
csv_file = fullfile('Data', 'Quick_Test', 'QuickTest_Database.csv');
T = readtable(csv_file);

target = T.Condition;
X = [T.FFT_H1, T.FFT_H2, T.PumpFlow, T.dPumpFlow, T.MAP, T.SBP, T.DBP];
feature_labels = {'FFT H1', 'FFT H2', 'PumpFlow', 'dPumpFlow', 'MAP', 'SBP', 'DBP'};

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

fig_folder = fullfile('Data', 'Quick_Test', 'Figures');
if ~exist(fig_folder, 'dir'), mkdir(fig_folder); end
saveas(gcf, fullfile(fig_folder, 'Feature_Importance.png'));

%% ============================================================
%   Leave-One-Feature-Out Analysis
%   Train KNN with ALL features, then remove one at a time
%   to see which feature causes the biggest accuracy drop.
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

saveas(gcf, fullfile(fig_folder, 'Feature_Drop_Analysis.png'));
fprintf('\nFigures saved to: %s\n', fig_folder);
