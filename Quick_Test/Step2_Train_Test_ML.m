%% ============================================================
%   QUICK TEST: Train & Evaluate ML Models
%   Loads the tiny dataset and trains 3 classifiers.
%   Run AFTER Step1_Build_QuickDB.m
% ============================================================

clc; close all;

%% Load Dataset
csv_file = fullfile('Data', 'Quick_Test', 'QuickTest_Database.csv');
if ~isfile(csv_file)
    error('Dataset not found. Run Step1_Build_QuickDB.m first.');
end

T = readtable(csv_file);
fprintf('Loaded %d samples from Quick Test dataset.\n\n', height(T));

%% Define Features and Target
target = T.Condition;
condition_names = {'Failing', 'Recovery', 'Normal'};

% Use ALL professor's features as inputs
X = [T.FFT_H1, T.FFT_H2, T.PumpFlow, T.dPumpFlow, T.MAP, T.SBP, T.DBP];
feature_labels = {'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', 'MAP', 'SBP', 'DBP'};

fprintf('Features: %s\n', strjoin(feature_labels, ', '));
fprintf('Classes:  %s\n\n', strjoin(condition_names, ', '));

%% Train/Test Split (70/30)
rng(42); % Fixed seed for reproducibility
cv = cvpartition(target, 'HoldOut', 0.3);
X_train = X(cv.training, :);
Y_train = target(cv.training);
X_test  = X(cv.test, :);
Y_test  = target(cv.test);

fprintf('Train: %d samples | Test: %d samples\n\n', sum(cv.training), sum(cv.test));

%% ============================================================
%   MODEL 1: DECISION TREE
% ============================================================
fprintf('--- Decision Tree ---\n');
mdl_tree = fitctree(X_train, Y_train, 'PredictorNames', feature_labels);
Y_pred_tree = predict(mdl_tree, X_test);
acc_tree = mean(Y_pred_tree == Y_test) * 100;
fprintf('  Accuracy: %.1f%%\n', acc_tree);

%% ============================================================
%   MODEL 2: K-NEAREST NEIGHBORS (k=5)
% ============================================================
fprintf('--- KNN (k=5) ---\n');
mdl_knn = fitcknn(X_train, Y_train, 'NumNeighbors', 5, 'Standardize', true);
Y_pred_knn = predict(mdl_knn, X_test);
acc_knn = mean(Y_pred_knn == Y_test) * 100;
fprintf('  Accuracy: %.1f%%\n', acc_knn);

%% ============================================================
%   MODEL 3: NAIVE BAYES
% ============================================================
fprintf('--- Naive Bayes ---\n');
mdl_nb = fitcnb(X_train, Y_train);
Y_pred_nb = predict(mdl_nb, X_test);
acc_nb = mean(Y_pred_nb == Y_test) * 100;
fprintf('  Accuracy: %.1f%%\n', acc_nb);

%% ============================================================
%   RESULTS COMPARISON
% ============================================================
fprintf('\n========== SUMMARY ==========\n');
fprintf('  Decision Tree: %.1f%%\n', acc_tree);
fprintf('  KNN (k=5):     %.1f%%\n', acc_knn);
fprintf('  Naive Bayes:   %.1f%%\n', acc_nb);
fprintf('  Dataset Size:  %d samples\n', height(T));
fprintf('=============================\n');

%% ============================================================
%   VISUALIZATION
% ============================================================

% --- Figure 1: Confusion Matrices (side by side) ---
figure('Name', 'Model Comparison', 'Color', 'w', 'Position', [100 100 1200 400]);

subplot(1,3,1);
confusionchart(Y_test, Y_pred_tree);
title(sprintf('Decision Tree (%.1f%%)', acc_tree));

subplot(1,3,2);
confusionchart(Y_test, Y_pred_knn);
title(sprintf('KNN k=5 (%.1f%%)', acc_knn));

subplot(1,3,3);
confusionchart(Y_test, Y_pred_nb);
title(sprintf('Naive Bayes (%.1f%%)', acc_nb));

sgtitle('Classification Results - Quick Test');

% --- Figure 2: Feature Space (2D projections) ---
figure('Name', 'Feature Space', 'Color', 'w', 'Position', [100 550 1200 400]);

subplot(1,3,1);
gscatter(T.PumpFlow, T.dPumpFlow, T.Condition, 'rbg', 'xo^');
xlabel('Pump Flow Pulsatility'); ylabel('dPumpFlow');
title('Pump Flow Features');
legend(condition_names, 'Location', 'northwest');
grid on;

subplot(1,3,2);
gscatter(T.FFT_H1, T.FFT_H2, T.Condition, 'rbg', 'xo^');
xlabel('FFT H1'); ylabel('FFT H2');
title('FFT Features');
legend(condition_names, 'Location', 'northwest');
grid on;

subplot(1,3,3);
gscatter(T.MAP, T.SBP, T.Condition, 'rbg', 'xo^');
xlabel('MAP (mmHg)'); ylabel('SBP (mmHg)');
title('Pressure Features');
legend(condition_names, 'Location', 'northwest');
grid on;

sgtitle('Feature Separability - Quick Test');

% --- Save Figures ---
fig_folder = fullfile('Data', 'Quick_Test', 'Figures');
if ~exist(fig_folder, 'dir'), mkdir(fig_folder); end
saveas(1, fullfile(fig_folder, 'Confusion_Matrices.png'));
saveas(2, fullfile(fig_folder, 'Feature_Space.png'));
fprintf('\nFigures saved to: %s\n', fig_folder);

% --- Save Models for Future Use ---
model_file = fullfile('Data', 'Quick_Test', 'Trained_ML_Models.mat');
save(model_file, 'mdl_tree', 'mdl_knn', 'mdl_nb', 'feature_labels');
fprintf('Trained models saved to: %s\n', model_file);
