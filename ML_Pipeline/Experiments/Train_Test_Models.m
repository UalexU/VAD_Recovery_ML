%% ============================================================
%   ML EXPERIMENT: Train & Evaluate Models
%   Loads a dataset from Generate_Focused_Dataset.m and trains
%   3 lightweight classifiers to test separability.
% ============================================================

clc; close all;

%% Load Dataset
experiment_name = 'Exp1_Preload_Separability';
dataset_file = fullfile('../..', 'Data', 'ML_Experiments', experiment_name, 'dataset.csv');

if ~isfile(dataset_file)
    error('Dataset not found. Run Generate_Focused_Dataset.m first.');
end

T = readtable(dataset_file);
fprintf('Loaded dataset: %s (%d samples)\n', experiment_name, height(T));

%% Feature Selection
% We assume the "Condition" column is the target (0=Failing, 1=Recovery, 2=Normal)
target = T.Condition;

% Features: Pump Flow Pulsatility, dPumpFlow, DeltaPumpPressure
features = [T.PumpFlow_Pulsatility, T.dPumpFlow_Pulsatility, T.DeltaPumpPressure];
feature_names = {'PumpFlow', 'dPumpFlow', 'DeltaPumpP'};

%% Train/Test Split (70/30)
cv = cvpartition(target, 'HoldOut', 0.3);
X_train = features(cv.training, :);
Y_train = target(cv.training, :);
X_test  = features(cv.test, :);
Y_test  = target(cv.test, :);

fprintf('\nData Split: %d Train / %d Test\n', size(X_train,1), size(X_test,1));

%% ============================================================
%                 MODEL 1: DECISION TREE
% ============================================================
fprintf('\n--- Training Decision Tree ---\n');
tree_model = fitctree(X_train, Y_train, ...
    'PredictorNames', feature_names, ...
    'MaxNumSplits', 10); % Simple tree to avoid overfitting

Y_pred_tree = predict(tree_model, X_test);
acc_tree = sum(Y_pred_tree == Y_test) / numel(Y_test);
fprintf('Accuracy: %.2f%%\n', acc_tree * 100);

% Confusion Matrix
figure('Name', 'Confusion Matrix - Decision Tree');
confusionchart(Y_test, Y_pred_tree);
title(['Decision Tree (Acc: ' num2str(acc_tree*100, '%.1f') '%)']);

%% ============================================================
%                 MODEL 2: K-NEAREST NEIGHBORS (KNN)
% ============================================================
fprintf('\n--- Training KNN (k=5) ---\n');
knn_model = fitcknn(X_train, Y_train, ...
    'NumNeighbors', 5, ...
    'Standardize', true); % Crucial for distance-based models

Y_pred_knn = predict(knn_model, X_test);
acc_knn = sum(Y_pred_knn == Y_test) / numel(Y_test);
fprintf('Accuracy: %.2f%%\n', acc_knn * 100);

%% ============================================================
%                 MODEL 3: NAIVE BAYES
% ============================================================
fprintf('\n--- Training Naive Bayes ---\n');
nb_model = fitcnb(X_train, Y_train, ...
    'DistributionNames', 'kernel'); % Kernel smoothing for non-normal features

Y_pred_nb = predict(nb_model, X_test);
acc_nb = sum(Y_pred_nb == Y_test) / numel(Y_test);
fprintf('Accuracy: %.2f%%\n', acc_nb * 100);

%% ============================================================
%                 VISUALIZATION (2D SLICE)
% ============================================================
% Plotting the decision boundary on the first two features
if size(features, 2) >= 2
    figure('Name', 'Decision Boundaries (KNN)');
    gscatter(X_test(:,1), X_test(:,2), Y_test, 'rbg', 'xo^');
    xlabel(feature_names{1});
    ylabel(feature_names{2});
    title(['KNN Classification (Acc: ' num2str(acc_knn*100, '%.1f') '%)']);
    legend({'Failing', 'Recovery', 'Normal'});
    grid on;
end
