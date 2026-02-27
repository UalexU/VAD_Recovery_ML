function plotComparisonLines(RPM_vec, feature_mat, feature_name, save_folder)
% plotComparisonLines - Creates a 2D line plot comparing different heart conditions
%
% Inputs:
%   RPM_vec      - Vector of RPM values (X-axis)
%   feature_mat  - 2D matrix [num_conditions x length(RPM)]
%   feature_name - String for labeling Y-axis and Title
%   save_folder  - (Optional) Path to save the figure

    fig = figure('Color', 'w', 'Name', ['Comparison: ', feature_name]);
    hold on; grid on;
    
    % Professional cardiovascular color palette
    % Blue = Normal, Orange = Recovery, Red/Gold = Failing
    colors = {[0 0.45 0.74], [0.85 0.33 0.1], [0.93 0.69 0.13]}; 
    styles = {'-', '--', '-.'};
    markers = {'o', 's', '^'};
    labels = {'Normal Heart', 'Recovery', 'Failing Heart'};
    
    num_conditions = size(feature_mat, 1);
    
    for i = 1:num_conditions
        plot(RPM_vec, feature_mat(i,:), ...
            'Color', colors{i}, ...
            'LineStyle', styles{i}, ...
            'Marker', markers{i}, ...
            'LineWidth', 2, ...
            'MarkerSize', 6, ...
            'DisplayName', labels{i});
    end
    
    % Formatting
    xlabel('Pump Speed (RPM k)', 'FontWeight', 'bold');
    ylabel(feature_name, 'FontWeight', 'bold');
    title(['Comparison of Heart Conditions: ', feature_name]);
    
    legend('Location', 'best', 'FontWeight', 'normal');
    set(gca, 'FontSize', 11);
    
    % Save Figure if folder provided
    if nargin > 3 && ~isempty(save_folder)
        if ~exist(save_folder, 'dir'), mkdir(save_folder); end
        
        % Clean filename
        clean_name = regexprep(feature_name, '[^a-zA-Z0-9]', '_');
        save_path = fullfile(save_folder, ['Comparison_', clean_name]);
        
        saveas(fig, [save_path, '.png']);
        fprintf('  Saved Comparison: %s.png\n', save_path);
    end
    
    hold off;
end
