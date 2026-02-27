%% 1. DATA LOADING AND SCATTERED POINT PREPARATION

% Load data blocks using the full paths provided
try
    % Emax = 1.0
    T_Normal = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\Preload\VusvSweep_Normal_PumpOff_8.csv');
    % Emax = 0.3
    T_Recovery = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\Preload\VusvSweep_Recovery_PumpOff_8.csv');
    % Emax = 0.18
    T_Failing = readtable('C:\Users\Admin\OneDrive\Documentos\MATLAB\Thesis\Simulations\Data\Sweep\Preload\VusvSweep_Failing_PumpOff_8.csv');
catch
    error('Could not load CSV files. Ensure file names and paths are correct.');
end

% --- Define the X (Emax), Y (Vusv), and Z (Psa_mean) vectors ---

% X_scattered: The discrete Strength Factor (Emax) for each block
% These are the confirmed Emax values
X1 = 1.0 * ones(height(T_Normal), 1); 
X2 = 0.3 * ones(height(T_Recovery), 1);
X3 = 0.18 * ones(height(T_Failing), 1);

% Y_scattered: Vusv (Y-axis) - Confirmed to be Column 2
Y1 = T_Normal{:, 2}; 
Y2 = T_Recovery{:, 2};
Y3 = T_Failing{:, 2};

% Z_scattered: Psa_mean (Mean Pressure - Z-axis) - Confirmed to be Column 5
Z1 = T_Normal{:, 5}; 
Z2 = T_Recovery{:, 5};
Z3 = T_Failing{:, 5};

% Combine all scattered data points into single long vectors
X_scattered = [X1; X2; X3];
Y_scattered = [Y1; Y2; Y3];
Z_scattered = [Z1; Z2; Z3];

%% 2. GRID DEFINITION AND INTERPOLATION

% Define the min/max range for the final grid based on the scattered data
Emax_min = min(X_scattered);
Emax_max = max(X_scattered);
Vusv_min = min(Y_scattered);
Vusv_max = max(Y_scattered);

% Create a uniform grid (e.g., 50x50 points) for plotting the smooth surface
N = 50;
[X_grid, Y_grid] = meshgrid(linspace(Emax_min, Emax_max, N), ...
                            linspace(Vusv_min, Vusv_max, N));

% Interpolate the scattered data onto the uniform grid
Z_interp = griddata(X_scattered, Y_scattered, Z_scattered, ...
                    X_grid, Y_grid, 'v4'); 

%% 3. 3D VISUALIZATION AND PLOTTING

figure('Name', 'Mean Pressure Surface Map');

% Use the surf function to create a 3D colored surface
surf(X_grid, Y_grid, Z_interp); 


% --- Plot Customization ---
xlabel('Strength Factor (E_{max})', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Vusv', 'FontSize', 12, 'FontWeight', 'bold');
zlabel('Mean Arterial Pressure (Psa_{mean})', 'FontSize', 12, 'FontWeight', 'bold');
title('3D Mean Pressure Map: E_{max} vs. Vusv', 'FontSize', 14, 'FontWeight', 'bold');

% Improve visualization:
colormap jet;          
colorbar;              % Shows the color scale for Psa_mean
shading interp;        % Smoothes color transitions
view(45, 30);          % Sets a good 3D viewing angle
grid on;

