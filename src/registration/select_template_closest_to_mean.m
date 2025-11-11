function template_idx = select_template_closest_to_mean(meshes)
% SELECT_TEMPLATE_CLOSEST_TO_MEAN Find specimen closest to preliminary mean
%
% Intelligent template initialization: computes preliminary mean shape
% and selects the specimen with lowest RMSE as template.
%
% Syntax:
%   idx = select_template_closest_to_mean(meshes)
%
% Inputs:
%   meshes - Cell array of mesh structs with .vertices field
%
% Outputs:
%   template_idx - Index of specimen closest to mean
%
% Algorithm (from paper section 2.4):
%   1. Center all meshes at origin
%   2. Compute preliminary mean shape (average of all vertices)
%   3. Compute RMSE from each mesh to mean
%   4. Return index of mesh with minimum RMSE
%
% See also: phase_registration
%
% Reference: JCM 2023 paper section 2.4

    num_meshes = length(meshes);

    % Check if all meshes have the same number of vertices
    num_vertices = cellfun(@(m) size(m.vertices, 1), meshes);

    if length(unique(num_vertices)) > 1
        % Meshes have different vertex counts - use centroid-based metric
        logger(sprintf('Meshes have varying vertex counts [%d-%d], using centroid-based selection', ...
            min(num_vertices), max(num_vertices)), 'level', 'DEBUG');

        % Center all meshes
        centroids = zeros(num_meshes, 3);
        for i = 1:num_meshes
            centroids(i, :) = mean(meshes{i}.vertices, 1);
        end

        % Compute mean centroid
        mean_centroid = mean(centroids, 1);

        % Compute distance from each mesh centroid to mean
        errors = sqrt(sum((centroids - mean_centroid).^2, 2));

        % Select mesh closest to mean centroid
        [min_error, template_idx] = min(errors);

        logger(sprintf('Template selection: centroid distances [%.2f, %.2f] mm, selected specimen %d', ...
            min(errors), max(errors), template_idx), 'level', 'DEBUG');
    else
        % All meshes have same vertex count - use vertex-wise comparison
        % Center all meshes
        meshes_centered = cell(num_meshes, 1);
        for i = 1:num_meshes
            centroid = mean(meshes{i}.vertices, 1);
            meshes_centered{i} = meshes{i}.vertices - centroid;
        end

        % Compute preliminary mean shape (simple average)
        mean_shape = zeros(size(meshes_centered{1}));
        for i = 1:num_meshes
            mean_shape = mean_shape + meshes_centered{i};
        end
        mean_shape = mean_shape / num_meshes;

        % Compute RMSE from each mesh to mean
        errors = zeros(num_meshes, 1);
        for i = 1:num_meshes
            diff = meshes_centered{i} - mean_shape;
            errors(i) = sqrt(mean(sum(diff.^2, 2)));
        end

        % Select mesh with minimum error
        [min_error, template_idx] = min(errors);

        logger(sprintf('Template selection: errors range [%.2f, %.2f] mm, selected specimen %d (error=%.2f mm)', ...
            min(errors), max(errors), template_idx, min_error), 'level', 'DEBUG');
    end

end
