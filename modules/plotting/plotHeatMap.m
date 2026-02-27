function plotHeatMap(Emax_vec, RPM_vec, feature_mat, feature_name, save_folder)
% plotHeatMap - Creates a 2D Heatmap for cardiovascular features
%
% Inputs:
%   Emax_vec     - Vector of Strength Factors (Y-axis)
%   RPM_vec      - Vector of RPM values (X-axis)
%   feature_mat  - 2D matrix [length(Emax) x length(RPM)]
%   feature_name - String for labeling Colorbar and Title
%   save_folder  - (Optional) Path to save the figure

    % Initialize figure
    fig = figure('Color', 'w', 'Name', ['Heatmap: ', feature_name]);
    
    % Create Heatmap using imagesc
    imagesc(feature_mat);
    colormap('parula'); % Consistent with default 3D color scheme
    
    % Axis Labels and Formatting
    xlabel('RPM (k)', 'FontWeight', 'bold');
    ylabel('Strength (Emax)', 'FontWeight', 'bold');
    title(sprintf('Heatmap: Effect of Emax and RPM on %s', feature_name));
    
    % Tick Configuration (X-Axis: RPM)
    numRPM = numel(RPM_vec);
    stepX = max(1, ceil(numRPM/10)); 
    xticks(1:stepX:numRPM);
    xticklabels(string(RPM_vec(1:stepX:end)));
    
    % Tick Configuration (Y-Axis: Emax)
    yticks(1:numel(Emax_vec));
    yticklabels(string(Emax_vec));
    
    % Aesthetics
    cb = colorbar;
    ylabel(cb, feature_name, 'FontSize', 10, 'FontWeight', 'bold'); % Label the colorbar
    set(gca, 'FontSize', 10, 'YDir', 'normal'); % 'normal' keeps Emax 1.0 at top/bottom as expected
    axis tight;
    
    % Save Figure if folder provided
    if nargin > 4 && ~isempty(save_folder)
        if ~exist(save_folder, 'dir'), mkdir(save_folder); end
        
        % Clean filename (remove special chars/spaces)
        clean_name = regexprep(feature_name, '[^a-zA-Z0-9]', '_');
        save_path = fullfile(save_folder, ['Heatmap_', clean_name]);
        
        saveas(fig, [save_path, '.png']);
        fprintf('  Saved Heatmap: %s.png\n', save_path);
    end
end
