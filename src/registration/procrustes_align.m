function meshes = procrustes_align(meshes, config)
% PROCRUSTES_ALIGN Generalized Procrustes Analysis for mesh alignment
%
% Performs iterative alignment to minimize total distance between all meshes
%
% Syntax:
%   meshes = procrustes_align(meshes, config)
%
% Inputs:
%   meshes - Cell array of mesh structs
%   config - Configuration struct
%
% Outputs:
%   meshes - Aligned mesh structs
%
% Example:
%   meshes = procrustes_align(meshes, config);

    num_meshes = length(meshes);
    num_vertices = size(meshes{1}.vertices, 1);

    % Stack all vertices
    X = zeros(num_vertices, 3, num_meshes);
    for i = 1:num_meshes
        X(:, :, i) = meshes{i}.vertices;
    end

    % Iterative Procrustes alignment
    max_iterations = 10;
    tolerance = 1e-6;

    for iter = 1:max_iterations
        % Compute mean shape
        mean_shape = mean(X, 3);

        % Align each shape to mean
        total_change = 0;
        for i = 1:num_meshes
            % Center both shapes
            shape_centered = X(:, :, i) - mean(X(:, :, i), 1);
            mean_centered = mean_shape - mean(mean_shape, 1);

            % Find rotation matrix using SVD
            [U, ~, V] = svd(mean_centered' * shape_centered);
            R = V * U';

            % Ensure proper rotation (det = 1)
            if det(R) < 0
                V(:, end) = -V(:, end);
                R = V * U';
            end

            % Apply rotation
            X_new = (R * shape_centered')';

            % Compute change
            change = norm(X_new - X(:, :, i), 'fro');
            total_change = total_change + change;

            X(:, :, i) = X_new;
        end

        % Check convergence
        if total_change / num_meshes < tolerance
            logger(sprintf('Procrustes converged after %d iterations', iter), 'level', 'DEBUG');
            break;
        end
    end

    % Update meshes
    for i = 1:num_meshes
        meshes{i}.vertices = X(:, :, i);
    end

end
