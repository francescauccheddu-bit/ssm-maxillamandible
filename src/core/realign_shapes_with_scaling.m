function [X_aligned, Y_aligned, Z_aligned, alignment_info] = realign_shapes_with_scaling(X_data, Y_data, Z_data)
% REALIGN_SHAPES_WITH_SCALING Normalize shapes with scaling to remove size effects
%
% Performs Procrustes-like alignment with scaling enabled to ensure that
% only shape variation (not size) is captured in the SSM. This prevents
% scale differences from dominating the principal components.
%
% Syntax:
%   [X_new, Y_new, Z_new, info] = realign_shapes_with_scaling(X, Y, Z)
%
% Inputs:
%   X_data - NxM matrix of X coordinates (N vertices, M specimens)
%   Y_data - NxM matrix of Y coordinates
%   Z_data - NxM matrix of Z coordinates
%
% Outputs:
%   X_aligned, Y_aligned, Z_aligned - Aligned and scaled coordinates
%   alignment_info - Information about transformation applied
%
% Algorithm:
%   For each specimen:
%     1. Center at origin
%     2. Compute scale (Frobenius norm)
%     3. Normalize by scale
%     4. Align to mean shape
%
% See also: build_ssm_complete

    [num_vertices, num_specimens] = size(X_data);

    % Initialize aligned data
    X_aligned = X_data;
    Y_aligned = Y_data;
    Z_aligned = Z_data;

    % Compute initial mean shape
    mean_X = mean(X_aligned, 2);
    mean_Y = mean(Y_aligned, 2);
    mean_Z = mean(Z_aligned, 2);

    % Iterative alignment (typically converges in 2-3 iterations)
    max_iterations = 5;
    tolerance = 1e-6;

    for iter = 1:max_iterations
        prev_mean = [mean_X; mean_Y; mean_Z];

        % Align each specimen to current mean
        for i = 1:num_specimens
            % Current shape
            shape = [X_aligned(:, i), Y_aligned(:, i), Z_aligned(:, i)];
            mean_shape = [mean_X, mean_Y, mean_Z];

            % Center both
            shape_center = mean(shape, 1);
            mean_center = mean(mean_shape, 1);

            shape_centered = shape - shape_center;
            mean_centered = mean_shape - mean_center;

            % Compute scale (Frobenius norm)
            scale_shape = sqrt(sum(shape_centered(:).^2) / num_vertices);
            scale_mean = sqrt(sum(mean_centered(:).^2) / num_vertices);

            % Normalize scale
            scale_factor = scale_mean / scale_shape;
            shape_scaled = shape_centered * scale_factor;

            % Compute rotation (Procrustes)
            H = shape_scaled' * mean_centered;
            [U, ~, V] = svd(H);
            R = V * U';

            % Handle reflection
            if det(R) < 0
                V(:, 3) = -V(:, 3);
                R = V * U';
            end

            % Apply transformation
            shape_aligned = (R * shape_scaled')' + mean_center;

            % Store aligned shape
            X_aligned(:, i) = shape_aligned(:, 1);
            Y_aligned(:, i) = shape_aligned(:, 2);
            Z_aligned(:, i) = shape_aligned(:, 3);
        end

        % Update mean
        mean_X = mean(X_aligned, 2);
        mean_Y = mean(Y_aligned, 2);
        mean_Z = mean(Z_aligned, 2);

        % Check convergence
        new_mean = [mean_X; mean_Y; mean_Z];
        change = norm(new_mean - prev_mean) / norm(new_mean);

        if change < tolerance
            break;
        end
    end

    % Package info
    alignment_info.iterations = iter;
    alignment_info.final_change = change;
    alignment_info.scaling_enabled = true;

end
