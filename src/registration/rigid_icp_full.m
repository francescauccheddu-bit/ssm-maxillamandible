function [vertices_aligned, transform_info] = rigid_icp_full(vertices_source, vertices_target, options)
% RIGID_ICP_FULL Complete rigid ICP with optional pre-alignment
%
% Performs rigid Iterative Closest Point alignment with optional PCA-based
% pre-alignment for meshes with large initial misalignment.
%
% Syntax:
%   [V_aligned, transform] = rigid_icp_full(V_source, V_target, options)
%
% Inputs:
%   vertices_source - Nx3 source vertex matrix
%   vertices_target - Mx3 target vertex matrix
%   options - Struct with fields:
%             .use_prealignment - Boolean, use PCA pre-alignment (default: true)
%             .max_iterations - Max ICP iterations (default: 50)
%             .tolerance - Convergence tolerance (default: 1e-6)
%             .free_edges_source - Indices of boundary vertices in source (optional)
%             .free_edges_target - Indices of boundary vertices in target (optional)
%
% Outputs:
%   vertices_aligned - Aligned source vertices
%   transform_info - Struct with:
%                    .R - Rotation matrix 3x3
%                    .t - Translation vector 1x3
%                    .s - Scale factor
%                    .error - Final alignment error
%                    .iterations - Number of iterations used
%
% Algorithm:
%   1. Optional: PCA-based pre-alignment
%   2. Iterative closest point refinement
%   3. Procrustes analysis for optimal rigid transform
%
% See also: nonrigid_icp_rbf, procrustes_alignment

    % Default options
    if nargin < 3 || isempty(options)
        options = struct();
    end
    if ~isfield(options, 'use_prealignment')
        options.use_prealignment = true;
    end
    if ~isfield(options, 'max_iterations')
        options.max_iterations = 50;
    end
    if ~isfield(options, 'tolerance')
        options.tolerance = 1e-6;
    end
    if ~isfield(options, 'free_edges_source')
        options.free_edges_source = [];
    end
    if ~isfield(options, 'free_edges_target')
        options.free_edges_target = [];
    end

    %% Step 1: Optional PCA pre-alignment
    if options.use_prealignment
        logger('Performing PCA-based pre-alignment...', 'level', 'DEBUG');
        [vertices_source, vertices_target, pretransform] = pca_prealignment(vertices_source, vertices_target);
    else
        pretransform = struct('applied', false);
    end

    %% Step 2: Iterative Closest Point
    V_current = vertices_source;
    prev_error = inf;

    for iter = 1:options.max_iterations
        % Find nearest neighbors (exclude boundary vertices if specified)
        if isempty(options.free_edges_target)
            [idx, distances] = knnsearch(vertices_target, V_current);
        else
            % Exclude boundary vertices from target
            valid_target = vertices_target;
            valid_target(options.free_edges_target, :) = [];
            [idx_temp, distances] = knnsearch(valid_target, V_current);
            % Map back to original indices
            valid_indices = setdiff(1:size(vertices_target,1), options.free_edges_target);
            idx = valid_indices(idx_temp)';
        end

        % Compute alignment error
        current_error = mean(distances);

        % Check convergence
        if abs(prev_error - current_error) < options.tolerance
            break;
        end
        prev_error = current_error;

        % Compute optimal rigid transformation
        V_matched = vertices_target(idx, :);
        [~, V_current, transform_iter] = procrustes(V_matched, V_current, 'Scaling', false, 'Reflection', false);
    end

    %% Step 3: Final Procrustes alignment
    [~, vertices_aligned, transform_final] = procrustes(vertices_target(idx, :), vertices_source, ...
        'Scaling', false, 'Reflection', false);

    %% Package output
    transform_info.R = transform_final.T;
    transform_info.t = transform_final.c(1, :);
    transform_info.s = transform_final.b;
    transform_info.error = current_error;
    transform_info.iterations = iter;
    transform_info.pretransform = pretransform;

    logger(sprintf('Rigid ICP converged: error=%.4f, iterations=%d', current_error, iter), ...
        'level', 'DEBUG');

end

%% Helper Functions

function [source_aligned, target_aligned, transform] = pca_prealignment(source, target)
    % PCA-based coarse alignment

    % Center both point clouds
    source_center = mean(source, 1);
    target_center = mean(target, 1);

    source_centered = source - source_center;
    target_centered = target - target_center;

    % Compute PCA for both
    [~, source_pca] = pca(source_centered);
    [~, target_pca] = pca(target_centered);

    % Scale to match size
    source_size = max(source_pca) - min(source_pca);
    target_size = max(target_pca) - min(target_pca);
    scale_factors = target_size ./ source_size;

    % Apply scaling
    source_scaled = source_pca .* scale_factors;

    % Find best 90-degree rotation using 8 cardinal orientations
    % (Original code used R.mat with 8 rotation matrices)
    best_error = inf;
    best_rotation = eye(3);

    for rx = 0:1
        for ry = 0:1
            for rz = 0:1
                % Try flipping each axis
                R_test = diag([(-1)^rx, (-1)^ry, (-1)^rz]);
                source_rotated = source_scaled * R_test;

                % Measure alignment error
                [idx, dists] = knnsearch(target_pca, source_rotated);
                error = sum(dists);

                if error < best_error
                    best_error = error;
                    best_rotation = R_test;
                end
            end
        end
    end

    % Apply best rotation
    source_aligned = source_scaled * best_rotation + target_center;
    target_aligned = target_pca + target_center;

    % Store transform
    transform.scale_factors = scale_factors;
    transform.rotation = best_rotation;
    transform.source_center = source_center;
    transform.target_center = target_center;
    transform.applied = true;
end
