function [transformed_vertices, transform] = rigid_icp(source_vertices, target_vertices, config)
% RIGID_ICP Rigid Iterative Closest Point alignment
%
% Usage:
%   [V_aligned, T] = rigid_icp(V_source, V_target, config)
%
% Parameters:
%   source_vertices - Nx3 source vertex coordinates
%   target_vertices - Mx3 target vertex coordinates
%   config - Configuration with .registration.rigid_icp settings
%
% Returns:
%   transformed_vertices - Nx3 aligned source vertices
%   transform - Struct with .R (rotation), .t (translation), .s (scale)
%
% Algorithm:
%   Iteratively find correspondences and compute optimal rigid transformation

    max_iter = config.registration.rigid_icp.iterations;
    tolerance = config.registration.rigid_icp.tolerance;

    V_source = source_vertices;
    V_target = target_vertices;

    % Initialize transform
    R = eye(3);
    t = zeros(1, 3);
    s = 1;

    prev_error = inf;

    for iter = 1:max_iter
        % Find nearest neighbors (correspondences)
        [idx, dist] = knnsearch(V_target, V_source);
        current_error = mean(dist);

        % Check convergence
        if abs(prev_error - current_error) < tolerance
            break;
        end
        prev_error = current_error;

        % Compute optimal transformation
        V_target_matched = V_target(idx, :);
        [R_iter, t_iter] = compute_rigid_transform(V_source, V_target_matched);

        % Apply transformation
        V_source = (R_iter * V_source')' + t_iter;

        % Accumulate transformation
        R = R_iter * R;
        t = t_iter + (R_iter * t')';
    end

    transformed_vertices = V_source;
    transform.R = R;
    transform.t = t;
    transform.s = s;
    transform.iterations = iter;
    transform.final_error = current_error;

end

function [R, t] = compute_rigid_transform(P, Q)
    % Compute rigid transformation from P to Q using SVD
    % P, Q are Nx3 matrices

    % Center point clouds
    centroid_P = mean(P, 1);
    centroid_Q = mean(Q, 1);

    P_centered = P - centroid_P;
    Q_centered = Q - centroid_Q;

    % Compute cross-covariance matrix
    H = P_centered' * Q_centered;

    % SVD
    [U, ~, V] = svd(H);

    % Rotation matrix
    R = V * U';

    % Handle reflection case
    if det(R) < 0
        V(:, 3) = -V(:, 3);
        R = V * U';
    end

    % Translation
    t = centroid_Q - (R * centroid_P')';

end
