function aligned_meshes = procrustes_align(meshes, config)
% PROCRUSTES_ALIGN Generalized Procrustes Analysis
%
% Usage:
%   meshes_aligned = procrustes_align(meshes, config)
%
% Parameters:
%   meshes - Cell array of mesh structs with .vertices (Nx3)
%   config - Configuration with .registration.procrustes settings
%
% Returns:
%   aligned_meshes - Cell array of aligned mesh structs
%
% Algorithm:
%   Iteratively align all shapes to their mean until convergence

    max_iter = config.registration.procrustes.max_iterations;
    tolerance = config.registration.procrustes.tolerance;
    allow_scaling = config.registration.procrustes.allow_scaling;

    num_meshes = length(meshes);
    num_vertices = size(meshes{1}.vertices, 1);

    logger('Performing Generalized Procrustes Analysis...');

    % Initialize: use first mesh as reference
    mean_shape = meshes{1}.vertices;

    for iter = 1:max_iter
        % Align all meshes to current mean
        aligned = cell(num_meshes, 1);

        for i = 1:num_meshes
            [aligned{i}.vertices, ~] = procrustes_single(meshes{i}.vertices, mean_shape, allow_scaling);
            aligned{i}.faces = meshes{i}.faces;
        end

        % Compute new mean
        new_mean_shape = zeros(num_vertices, 3);
        for i = 1:num_meshes
            new_mean_shape = new_mean_shape + aligned{i}.vertices;
        end
        new_mean_shape = new_mean_shape / num_meshes;

        % Check convergence
        mean_diff = norm(new_mean_shape(:) - mean_shape(:));
        if mean_diff < tolerance
            logger(sprintf('Procrustes converged in %d iterations', iter));
            break;
        end

        mean_shape = new_mean_shape;
    end

    aligned_meshes = aligned;

end

function [aligned, transform] = procrustes_single(source, target, allow_scaling)
    % Align source to target using Procrustes analysis

    % Center both shapes
    centroid_source = mean(source, 1);
    centroid_target = mean(target, 1);

    source_centered = source - centroid_source;
    target_centered = target - centroid_target;

    % Compute scale
    if allow_scaling
        scale_source = sqrt(sum(source_centered(:).^2) / size(source, 1));
        scale_target = sqrt(sum(target_centered(:).^2) / size(target, 1));
        scale = scale_target / scale_source;
    else
        scale = 1;
    end

    % Scale source
    source_scaled = source_centered * scale;

    % Compute rotation (SVD)
    H = source_scaled' * target_centered;
    [U, ~, V] = svd(H);
    R = V * U';

    % Handle reflection
    if det(R) < 0
        V(:, 3) = -V(:, 3);
        R = V * U';
    end

    % Apply transformation
    aligned = (R * source_scaled')' + centroid_target;

    % Store transform
    transform.R = R;
    transform.t = centroid_target - (R * (scale * centroid_source)')';
    transform.s = scale;

end
