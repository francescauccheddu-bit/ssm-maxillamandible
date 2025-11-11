function [vertices_registered, registration_info] = nonrigid_icp_rbf(vertices_source, faces_source, vertices_target, faces_target, options)
% NONRIGID_ICP_RBF Non-rigid ICP using Radial Basis Function deformation
%
% Performs non-rigid registration allowing local deformations using RBF
% interpolation with Gaussian kernels. Combines global deformation with
% local optimization for high-quality mesh alignment.
%
% Syntax:
%   [V_reg, info] = nonrigid_icp_rbf(V_src, F_src, V_tgt, F_tgt, opts)
%
% Inputs:
%   vertices_source - Nx3 source mesh vertices
%   faces_source    - Mx3 source mesh faces
%   vertices_target - Px3 target mesh vertices
%   faces_target    - Qx3 target mesh faces
%   options - Struct with:
%             .iterations - Number of iterations (default: 15)
%             .lambda - Regularization parameter (default: 0.001)
%             .use_rigid_prealign - Use rigid ICP first (default: true)
%             .k_neighbors - k-NN for local optimization (default: 12)
%
% Outputs:
%   vertices_registered - Registered source vertices
%   registration_info - Struct with registration details
%
% Algorithm:
%   Phase 1: Optional rigid pre-alignment
%   Phase 2: Global RBF deformation (coarse-to-fine)
%   Phase 3: Local optimization using weighted Procrustes
%
% Performance: O(N*M*iterations) where N,M are vertex counts
%
% See also: rigid_icp_full

    % Parse options
    if nargin < 5, options = struct(); end
    if ~isfield(options, 'iterations'), options.iterations = 15; end
    if ~isfield(options, 'lambda'), options.lambda = 0.001; end
    if ~isfield(options, 'use_rigid_prealign'), options.use_rigid_prealign = true; end
    if ~isfield(options, 'k_neighbors'), options.k_neighbors = 12; end

    logger('Non-rigid ICP with RBF deformation...', 'level', 'INFO');

    % Remove duplicate vertices
    [vertices_target, ~, idx_map] = unique(vertices_target, 'rows', 'stable');
    faces_target = idx_map(faces_target);

    % Detect free edges (boundaries)
    free_edges_source = detect_free_edges(vertices_source, faces_source);
    free_edges_target = detect_free_edges(vertices_target, faces_target);

    if ~isempty(free_edges_source) || ~isempty(free_edges_target)
        logger('Warning: Mesh contains boundaries', 'level', 'WARNING');
    end

    %% Phase 1: Rigid pre-alignment
    V_current = vertices_source;

    if options.use_rigid_prealign
        logger('Rigid pre-alignment...', 'level', 'DEBUG');
        rigid_opts.use_prealignment = true;
        rigid_opts.max_iterations = 30;
        rigid_opts.free_edges_source = free_edges_source;
        rigid_opts.free_edges_target = free_edges_target;

        [V_current, ~] = rigid_icp_full(V_current, vertices_target, rigid_opts);
    end

    %% Phase 2: Global RBF Deformation
    logger('Global RBF deformation...', 'level', 'DEBUG');

    % Adaptive RBF kernel schedule (coarse to fine)
    kernel_schedule = linspace(1.5, 1.0, options.iterations);
    seeding_schedule = linspace(2.1, 2.4, options.iterations);

    % Bounding box for RBF control points
    bbox_min = min(V_current, [], 1);
    bbox_max = max(V_current, [], 1);
    bbox_size = bbox_max - bbox_min;
    min_bbox_dim = min(bbox_size);

    for iter = 1:options.iterations
        % Create RBF control point grid
        num_control_points = round(10^seeding_schedule(iter));
        grid_spacing = min_bbox_dim / (num_control_points^(1/3));

        [control_points] = create_control_grid(bbox_min, bbox_max, grid_spacing);

        % Find correspondences (excluding boundaries)
        valid_source_idx = setdiff(1:size(V_current,1), free_edges_source);
        valid_target_idx = setdiff(1:size(vertices_target,1), free_edges_target);

        % Nearest neighbor search
        [idx_st, ~] = knnsearch(vertices_target(valid_target_idx,:), V_current(valid_source_idx,:));
        % idx_st are local indices into valid_target_idx (1 to length(valid_target_idx))

        [idx_ts, ~] = knnsearch(V_current(valid_source_idx,:), vertices_target(valid_target_idx,:));
        % idx_ts are local indices into valid_source_idx (1 to length(valid_source_idx))

        % Build correspondence sets
        source_partial = V_current(valid_source_idx, :);
        target_partial = vertices_target(valid_target_idx, :);

        % Symmetric correspondences
        % idx_st and idx_ts are already local indices, so can be used directly
        source_extended = [source_partial; source_partial(idx_ts, :)];
        target_extended = [target_partial(idx_st, :); target_partial];

        % Compute RBF deformation
        displacement = target_extended - source_extended;

        % RBF matrix (Gaussian kernel)
        D = pdist2(source_extended, control_points);
        gamma = 1 / (2 * (mean(D(:)))^kernel_schedule(iter));
        RBF = exp(-gamma * D.^2);

        % Expand for 3D (x,y,z)
        num_corr = size(source_extended, 1);
        num_control = size(control_points, 1);

        RBF_full = zeros(3*num_corr, 3*num_control);
        for d = 1:3
            idx_row = (d-1)*num_corr + (1:num_corr);
            idx_col = (d-1)*num_control + (1:num_control);
            RBF_full(idx_row, idx_col) = RBF;
        end

        % Solve for RBF weights (with regularization)
        weights = (RBF_full' * RBF_full + options.lambda * eye(3*num_control)) \ ...
                  (RBF_full' * displacement(:));

        % Apply deformation to all source vertices
        D_full = pdist2(V_current, control_points);
        gamma_full = 1 / (2 * (mean(D_full(:)))^kernel_schedule(iter));
        RBF_full_apply = exp(-gamma_full * D_full.^2);

        % Compute displacement for all vertices
        num_vertices = size(V_current, 1);
        deformation = zeros(num_vertices, 3);

        for d = 1:3
            idx_weights = (d-1)*num_control + (1:num_control);
            deformation(:, d) = RBF_full_apply * weights(idx_weights);
        end

        % Apply deformation
        V_current = V_current + deformation;

        % Rigid refinement
        [V_current, ~] = rigid_icp_full(V_current, vertices_target, ...
            struct('use_prealignment', false, 'max_iterations', 5));

        if mod(iter, 5) == 0
            logger(sprintf('  Iteration %d/%d complete', iter, options.iterations), 'level', 'DEBUG');
        end
    end

    %% Phase 3: Local Optimization (weighted Procrustes)
    logger('Local optimization...', 'level', 'DEBUG');

    k_schedule = options.k_neighbors + options.iterations - (1:options.iterations);

    for iter = 1:options.iterations
        k = k_schedule(iter);

        % Build local neighborhoods
        [neighbor_idx, neighbor_dist] = knnsearch(V_current, V_current, 'K', k);

        % Compute distance weights
        sum_dist = sum(neighbor_dist(:, 1:k), 2);
        weights_matrix = (repmat(sum_dist, 1, k) - neighbor_dist(:, 1:k)) ./ ...
                        (repmat(sum_dist, 1, k) * (k-1));

        % Find target correspondences
        [target_idx, ~] = knnsearch(vertices_target, V_current, 'K', 3);

        % Weighted target positions
        target_positions = zeros(size(V_current));
        for i = 1:size(V_current, 1)
            target_pts = vertices_target(target_idx(i, :), :);
            dists = sqrt(sum((target_pts - V_current(i,:)).^2, 2));
            w = (sum(dists) - dists) / (sum(dists) * 2);
            target_positions(i, :) = sum(target_pts .* w, 1);
        end

        % Local Procrustes for each vertex
        V_new = V_current;
        for i = 1:size(V_current, 1)
            local_source = V_current(neighbor_idx(i, 1:k), :);
            local_target = target_positions(neighbor_idx(i, 1:k), :);

            [~, ~, transform] = procrustes(local_target, local_source, ...
                'Scaling', false, 'Reflection', false);

            % Weighted contribution
            for j = 1:k
                v_idx = neighbor_idx(i, j);
                V_new(i, :) = V_new(i, :) + weights_matrix(i, j) * ...
                    (transform.b * V_current(i, :) * transform.T + transform.c(1, :));
            end
        end

        % Damped update
        V_current = 0.5 * V_current + 0.5 * V_new;
    end

    %% Output
    vertices_registered = V_current;

    registration_info.num_iterations = options.iterations;
    registration_info.had_boundaries = ~isempty(free_edges_source) || ~isempty(free_edges_target);

    logger('Non-rigid ICP complete', 'level', 'INFO');

end

%% Helper Functions

function control_points = create_control_grid(bbox_min, bbox_max, spacing)
    % Create regular 3D grid of control points

    x_range = bbox_min(1):spacing:bbox_max(1);
    y_range = bbox_min(2):spacing:bbox_max(2);
    z_range = bbox_min(3):spacing:bbox_max(3);

    [X, Y, Z] = ndgrid(x_range, y_range, z_range);

    control_points = [X(:), Y(:), Z(:)];
end
