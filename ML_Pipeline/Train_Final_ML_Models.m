%% ============================================================
%   TRAIN FINAL ML MODELS (Thesis/Publication Quality)
%   Loads the full compiled database and performs rigorous
%   training and validation.
% ============================================================

clc; clear; close all;

%% 1. Load Compiled Database
% --- CHANGE THIS TO YOUR SHARED DRIVE PATH ---
SHARED_DRIVE_PATH = ''; 

if isempty(SHARED_DRIVE_PATH)
    db_file = fullfile('Data', 'ML_Database', 'ML_Master_Database.csv');
else
    db_file = fullfile(SHARED_DRIVE_PATH, 'ML_Master_Database.csv');
end

if ~isfile(db_file)
    error('Master Database not found at %s. Run Compile_Master_Database.m first.', db_file);
end

T = readtable(db_file);
fprintf('Successfully loaded %d simulations.\n', height(T));

%% 2. Define Features and Target
% Target: Condition (0=Failing, 1=Recovery, 2=Normal)
Y = T.Condition;
class_names = {'Failing', 'Recovery', 'Normal'};

% Features: Professor's Final List
feature_names = {'FFT_H1', 'FFT_H2', 'PumpFlow', 'dPumpFlow', 'MAP', 'SBP', 'DBP'};
X = T{:, feature_names};

fprintf('Features used: %s\n', strjoin(feature_names, ', '));

%% 3. Partition Data (80% Train, 20% Test)
rng(42); % For reproducibility
cv = cvpartition(Y, 'HoldOut', 0.20);
X_train = X(training(cv), :);
Y_train = Y(training(cv));
X_test  = X(test(cv), :);
Y_test  = Y(test(cv));

fprintf('Training set: %d samples\n', size(X_train, 1));
fprintf('Testing set:  %d samples\n\n', size(X_test, 1));

%% 4. Model A: K-Nearest Neighbors (KNN)
% Optimized for large datasets with standardization
fprintf('Training Optimized KNN... ');
tic;
mdl_knn = fitcknn(X_train, Y_train, ...
    'NumNeighbors', 5, ...
    'Standardize', true, ...
    'Distance', 'Euclidean');
t_knn = toc;
Y_pred_knn = predict(mdl_knn, X_test);
acc_knn = mean(Y_pred_knn == Y_test) * 100;
fprintf('Done (%.1fs). Accuracy: %.2f%%\n', t_knn, acc_knn);

%% 5. Model B: Decision Tree
fprintf('Training Decision Tree... ');
tic;
mdl_tree = fitctree(X_train, Y_train, ...
    'PredictorNames', feature_names, ...
    'MaxNumSplits', 20); % Limited depth to prevent overfitting
t_tree = toc;
Y_pred_tree = predict(mdl_tree, X_test);
acc_tree = mean(Y_pred_tree == Y_test) * 100;
fprintf('Done (%.1fs). Accuracy: %.2f%%\n', t_tree, acc_tree);

%% 6. Model C: Naive Bayes
fprintf('Training Naive Bayes... ');
tic;
mdl_nb = fitcnb(X_train, Y_train, 'DistributionNames', 'kernel');
t_nb = toc;
Y_pred_nb = predict(mdl_nb, X_test);
acc_nb = mean(Y_pred_nb == Y_test) * 100;
fprintf('Done (%.1fs). Accuracy: %.2f%%\n', t_nb, acc_nb);

%% 7. Cross-Validation (Proof of Robustness)
fprintf('\nPerforming 10-Fold Cross-Validation on best model (KNN)... ');
cv_mdl = crossval(mdl_knn, 'KFold', 10);
cv_loss = kfoldLoss(cv_mdl);
fprintf('Done.\nCV Accuracy: %.2f%%\n', (1-cv_loss)*100);

%% 8. Visualization
figure('Name', 'Final Model Performance', 'Color', 'w', 'Position', [100 100 1000 400]);

% Confusion Matrix for KNN
subplot(1,2,1);
confusionchart(Y_test, Y_pred_knn, 'Title', 'KNN Confusion Matrix', ...
    'RowSummary','row-normalized', 'ColumnSummary','column-normalized');

% Feature Importance (from Tree)
subplot(1,2,2);
imp = predictorImportance(mdl_tree);
[sorted_imp, idx] = sort(imp, 'descend');
bar(sorted_imp, 'FaceColor', [0.2 0.6 0.8]);
set(gca, 'XTickLabel', feature_names(idx), 'XTickLabelRotation', 45);
title('Feature Importance (Weight)');
ylabel('Importance Score');
grid on;

%% 9. Save Final Product
% --- CHANGE THIS TO YOUR SHARED DRIVE PATH ---
SHARED_DRIVE_PATH = 'G:\My Drive\Thesis Data'; 

if isempty(SHARED_DRIVE_PATH)
    results_folder = fullfile('Data', 'Final_Results');
else
    results_folder = fullfile(SHARED_DRIVE_PATH, 'Final_Results');
end

if ~exist(results_folder, 'dir'), mkdir(results_folder); end

save(fullfile(results_folder, 'Final_Heart_Models.mat'), ...
    'mdl_knn', 'mdl_tree', 'mdl_nb', 'feature_names');

fprintf('\nFinal Models saved to: %s\n', results_folder);
