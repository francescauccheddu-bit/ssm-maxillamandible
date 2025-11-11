function use_ssm(varargin)
% USE_SSM Load saved SSM and generate results (like paper visualizations)
%
% This script loads a pre-computed SSM model and generates results without
% recomputing preprocessing/registration. Use this after running the full
% pipeline at least once.
%
% Usage:
%   use_ssm()                           % Use default SSM
%   use_ssm('model', 'path/to/ssm.mat') % Use specific model
%   use_ssm('export_modes', true)       % Export PCA mode variations
%   use_ssm('num_modes', 5)             % Export first 5 modes
%
% Examples:
%   % Generate all visualizations from saved model
%   use_ssm()
%
%   % Export specific number of modes
%   use_ssm('num_modes', 3, 'export_modes', true)
%
% See also: run_pipeline

    %% Parse input
    p = inputParser;
    addParameter(p, 'model', 'output/ssm_model.mat', @ischar);
    addParameter(p, 'export_modes', true, @islogical);
    addParameter(p, 'num_modes', 3, @isnumeric);
    addParameter(p, 'std_range', [-3, -2, -1, 0, 1, 2, 3], @isnumeric);
    addParameter(p, 'output_dir', 'output/ssm_results', @ischar);
    parse(p, varargin{:});

    model_path = p.Results.model;
    export_modes = p.Results.export_modes;
    num_modes = p.Results.num_modes;
    std_range = p.Results.std_range;
    output_dir = p.Results.output_dir;

    %% Setup
    [script_dir, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(script_dir, 'src')));

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  Using Saved SSM Model\n');
    fprintf('========================================\n\n');

    %% Load model
    if ~exist(model_path, 'file')
        error('SSM model not found: %s\nRun the full pipeline first: run_pipeline()', model_path);
    end

    fprintf('Loading SSM model: %s\n', model_path);
    tic;
    data = load(model_path);
    ssm_model = data.ssm_model;
    elapsed = toc;
    fprintf('Loaded in %.1f seconds\n\n', elapsed);

    %% Display model info
    display_ssm_info(ssm_model);

    %% Create output directory
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    %% Export mean shape
    fprintf('\n--- Exporting Mean Shape ---\n');
    export_mean_shape(ssm_model, output_dir);

    %% Export PCA modes
    if export_modes
        fprintf('\n--- Exporting PCA Mode Variations ---\n');
        export_pca_modes(ssm_model, num_modes, std_range, output_dir);
    end

    %% Generate statistics report
    fprintf('\n--- Generating Statistics Report ---\n');
    generate_statistics_report(ssm_model, output_dir);

    %% Summary
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('Results saved to: %s\n', output_dir);
    fprintf('========================================\n\n');

end

%% Helper Functions

function display_ssm_info(ssm_model)
    % Display SSM model information
    fprintf('--- SSM Model Information ---\n');
    fprintf('Specimens:       %d\n', ssm_model.num_specimens);
    fprintf('Vertices:        %d\n', ssm_model.num_vertices);
    fprintf('Components:      %d\n', ssm_model.num_components);

    if isfield(ssm_model, 'explained_variance')
        fprintf('\nVariance Explained:\n');
        cumvar = cumsum(ssm_model.explained_variance);
        for i = 1:min(10, length(cumvar))
            fprintf('  PC%d:  %.1f%% (cumulative: %.1f%%)\n', ...
                i, ssm_model.explained_variance(i), cumvar(i));
        end

        % Find number of PCs for 90%, 95%, 99%
        idx_90 = find(cumvar >= 90, 1);
        idx_95 = find(cumvar >= 95, 1);
        idx_99 = find(cumvar >= 99, 1);
        fprintf('\n  %d PCs capture 90%% variance\n', idx_90);
        fprintf('  %d PCs capture 95%% variance\n', idx_95);
        fprintf('  %d PCs capture 99%% variance\n', idx_99);
    end
end

function export_mean_shape(ssm_model, output_dir)
    % Export mean shape as STL
    mean_vertices = [ssm_model.mean_shape.X, ssm_model.mean_shape.Y, ssm_model.mean_shape.Z];

    % Use faces from first specimen (topology is same for all)
    if isfield(ssm_model, 'faces')
        faces = ssm_model.faces;
    else
        warning('No face information in SSM model. Cannot export mean shape.');
        return;
    end

    output_file = fullfile(output_dir, 'mean_shape.stl');
    write_stl(output_file, mean_vertices, faces);
    fprintf('Mean shape saved: %s\n', output_file);
end

function export_pca_modes(ssm_model, num_modes, std_range, output_dir)
    % Export PCA mode variations

    num_modes = min(num_modes, ssm_model.num_components);

    for mode_idx = 1:num_modes
        fprintf('Exporting mode %d/%d...\n', mode_idx, num_modes);

        % Get principal component
        pc_x = ssm_model.principal_components.X(:, mode_idx);
        pc_y = ssm_model.principal_components.Y(:, mode_idx);
        pc_z = ssm_model.principal_components.Z(:, mode_idx);

        % Get eigenvalue (for scaling)
        eigenval = ssm_model.eigenvalues(mode_idx);
        std_dev = sqrt(eigenval);

        for std_mult in std_range
            % Generate shape: mean + std_mult * std_dev * PC
            vertices = [
                ssm_model.mean_shape.X + std_mult * std_dev * pc_x, ...
                ssm_model.mean_shape.Y + std_mult * std_dev * pc_y, ...
                ssm_model.mean_shape.Z + std_mult * std_dev * pc_z
            ];

            % Export
            filename = sprintf('mode%d_std%+d.stl', mode_idx, std_mult);
            output_file = fullfile(output_dir, filename);
            write_stl(output_file, vertices, ssm_model.faces);
        end

        fprintf('  Variance explained: %.2f%%\n', ssm_model.explained_variance(mode_idx));
    end

    fprintf('Exported %d modes with %d variations each\n', num_modes, length(std_range));
end

function generate_statistics_report(ssm_model, output_dir)
    % Generate text report with statistics

    report_file = fullfile(output_dir, 'ssm_statistics.txt');
    fid = fopen(report_file, 'w');

    fprintf(fid, '========================================\n');
    fprintf(fid, ' SSM Statistics Report\n');
    fprintf(fid, '========================================\n\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));

    fprintf(fid, '--- Model Summary ---\n');
    fprintf(fid, 'Number of specimens:     %d\n', ssm_model.num_specimens);
    fprintf(fid, 'Number of vertices:      %d\n', ssm_model.num_vertices);
    fprintf(fid, 'Number of components:    %d\n', ssm_model.num_components);
    fprintf(fid, '\n');

    if isfield(ssm_model, 'explained_variance')
        fprintf(fid, '--- Variance Explained by Principal Components ---\n');
        cumvar = cumsum(ssm_model.explained_variance);
        for i = 1:ssm_model.num_components
            fprintf(fid, 'PC%2d: %6.2f%% (cumulative: %6.2f%%)\n', ...
                i, ssm_model.explained_variance(i), cumvar(i));
        end
        fprintf(fid, '\n');

        % Milestones
        idx_90 = find(cumvar >= 90, 1);
        idx_95 = find(cumvar >= 95, 1);
        idx_99 = find(cumvar >= 99, 1);
        fprintf(fid, '--- Variance Milestones ---\n');
        fprintf(fid, '90%% variance captured by %d components\n', idx_90);
        fprintf(fid, '95%% variance captured by %d components\n', idx_95);
        fprintf(fid, '99%% variance captured by %d components\n', idx_99);
        fprintf(fid, '\n');
    end

    if isfield(ssm_model, 'eigenvalues')
        fprintf(fid, '--- Eigenvalues (Top 10) ---\n');
        for i = 1:min(10, length(ssm_model.eigenvalues))
            fprintf(fid, 'PC%2d: %e\n', i, ssm_model.eigenvalues(i));
        end
        fprintf(fid, '\n');
    end

    fclose(fid);
    fprintf('Statistics report saved: %s\n', report_file);
end
