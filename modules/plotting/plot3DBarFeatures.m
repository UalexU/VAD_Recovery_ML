function plot3DBarFeatures(Emax_vec, RPM_vec, feature_mat, feature_name, save_folder)
% plot3DBarFeatures - Creates a 3D bar chart and optionally saves it
%
% Inputs:
%   Emax_vec     - Vector of Strength Factors (Y-axis)
%   RPM_vec      - Vector of RPM values (X-axis)
%   feature_mat  - 2D matrix [length(Emax) x length(RPM)]
%   feature_name - String for labeling Z-axis and Title
%   save_folder  - (Optional) Path to save the figure

    % Initialize figure
    fig = figure('Color', 'w', 'Name', ['3D Analysis: ', feature_name]);
    
    % Create 3D bar chart
    h = bar3(feature_mat);
    
    % Color bars by height (Z-value)
    for k = 1:numel(h)
        h(k).CData = h(k).ZData;
        h(k).FaceColor = 'interp';
    end
    
    % Axis Labels and Formatting
    xlabel('RPM (k)', 'FontWeight', 'bold');
    ylabel('Strength (Emax)', 'FontWeight', 'bold');
    zlabel(feature_name, 'FontWeight', 'bold');
    title(sprintf('Effect of Emax and RPM on %s', feature_name));
    
    % Tick Configuration (X-Axis: RPM)
    numRPM = numel(RPM_vec);
    stepX = max(1, ceil(numRPM/10)); 
    xticks(1:stepX:numRPM);
    xticklabels(string(RPM_vec(1:stepX:end)));
    
    % Tick Configuration (Y-Axis: Emax)
    yticks(1:numel(Emax_vec));
    yticklabels(string(Emax_vec));
    
    % View Aesthetics
    view(-37.5, 30); 
    cb = colorbar;
    ylabel(cb, feature_name, 'FontSize', 10, 'FontWeight', 'bold'); % Label the colorbar
    grid on;
    
    % Refine Z-axis clarity
    ax = gca;
    ax.FontSize = 10;
    ax.ZGrid = 'on';
    ax.Box = 'on'; % Adds a box around the 3D plot for better depth perception
    
    % Enhance bar visibility (Edge coloring)
    for k = 1:numel(h)
        h(k).EdgeColor = [0.2 0.2 0.2]; % Dark grey edges make bars pop
        h(k).FaceAlpha = 0.85;        % Slight transparency to see bars behind
    end

    % Save Figure if folder provided
    if nargin > 4 && ~isempty(save_folder)
        if ~exist(save_folder, 'dir'), mkdir(save_folder); end
        
        % Clean filename (remove special chars/spaces)
        clean_name = regexprep(feature_name, '[^a-zA-Z0-9]', '_');
        save_path = fullfile(save_folder, ['3D_Plot_', clean_name]);
        
        saveas(fig, [save_path, '.png']);
        % saveas(fig, [save_path, '.fig']); % Uncomment to save MATLAB .fig files
        fprintf('  Saved plot: %s.png\n', save_path);
    end
end
