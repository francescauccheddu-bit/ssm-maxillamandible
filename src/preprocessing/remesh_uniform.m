function [vertices_remeshed, faces_remeshed, stats] = remesh_uniform(vertices, faces, target_edge_length, num_iterations)
% REMESH_UNIFORM Isotropic remeshing to achieve uniform edge lengths
%
% Performs iterative remeshing to achieve approximately uniform edge lengths
% throughout the mesh using edge collapse and subdivision operations.
%
% Syntax:
%   [V_new, F_new, stats] = remesh_uniform(V, F, target_length, num_iter)
%
% Inputs:
%   vertices          - Nx3 vertex matrix
%   faces             - Mx3 face matrix
%   target_edge_length - Desired edge length (in same units as vertices)
%   num_iterations    - Number of remeshing iterations (typically 3-10)
%
% Outputs:
%   vertices_remeshed - Remeshed vertex matrix
%   faces_remeshed    - Remeshed face matrix
%   stats             - Struct with:
%                       .mean_edge_length - Final mean edge length
%                       .std_edge_length  - Final std deviation
%                       .num_vertices     - Final vertex count
%                       .num_faces        - Final face count
%
% Algorithm:
%   For each iteration:
%     1. Clean mesh (remove duplicates and degenerates)
%     2. Collapse edges shorter than 0.8 * target
%     3. Subdivide edges longer than 1.5 * target
%     4. Remove degenerate triangles
%     5. Smooth vertices (optional)
%
% Example:
%   [V, F] = read_stl('mandible.stl');
%   [V_remeshed, F_remeshed, stats] = remesh_uniform(V, F, 1.0, 5);
%   fprintf('Final edge length: %.2f ± %.2f mm\n', ...
%           stats.mean_edge_length, stats.std_edge_length);
%
% Note: This is a simplified remeshing implementation. For production use
%       with large meshes, consider external libraries (iso2mesh, gptoolbox).
%
% See also: clean_mesh, subdivide_large_edges

    % Default parameters
    if nargin < 4
        num_iterations = 5;
    end
    if nargin < 3
        target_edge_length = 1.0;
    end

    % Validate inputs
    if size(faces, 2) ~= 3
        error('remesh_uniform:InvalidInput', 'Faces must be Mx3 matrix');
    end

    logger('Remeshing to target edge length: %.2f mm', target_edge_length);

    % Initial cleanup
    [vertices_remeshed, faces_remeshed] = clean_mesh(vertices, faces);

    % Initial statistics
    [mean_initial, std_initial] = compute_edge_statistics(vertices_remeshed, faces_remeshed);
    logger('Initial edge length: %.2f ± %.2f mm', mean_initial, std_initial);

    % Remeshing iterations
    for iter = 1:num_iterations
        logger(sprintf('Remeshing iteration %d/%d...', iter, num_iterations), ...
            'level', 'DEBUG');

        % 1. Edge collapse (merge short edges)
        min_edge_length = target_edge_length * 0.8;
        [vertices_remeshed, faces_remeshed] = collapse_short_edges_simple(vertices_remeshed, faces_remeshed, min_edge_length);

        % 2. Edge subdivision (split long edges)
        max_edge_length = target_edge_length * 1.5;
        [vertices_remeshed, faces_remeshed] = subdivide_large_edges(vertices_remeshed, faces_remeshed, max_edge_length);

        % 3. Clean up degenerate faces
        [vertices_remeshed, faces_remeshed] = clean_mesh(vertices_remeshed, faces_remeshed);

        % 4. Optional: Laplacian smoothing (light touch)
        if iter < num_iterations  % Don't smooth on last iteration
            vertices_remeshed = laplacian_smooth_vertices(vertices_remeshed, faces_remeshed, 0.3);
        end

        % Log progress
        [mean_current, std_current] = compute_edge_statistics(vertices_remeshed, faces_remeshed);
        logger(sprintf('  Edge length: %.2f ± %.2f mm, %d vertices, %d faces', ...
            mean_current, std_current, size(vertices_remeshed,1), size(faces_remeshed,1)), ...
            'level', 'DEBUG');
    end

    % Final statistics
    [mean_final, std_final] = compute_edge_statistics(vertices_remeshed, faces_remeshed);

    stats.mean_edge_length = mean_final;
    stats.std_edge_length = std_final;
    stats.num_vertices = size(vertices_remeshed, 1);
    stats.num_faces = size(faces_remeshed, 1);

    logger('Remeshing complete: %.2f ± %.2f mm, %d vertices, %d faces', ...
        mean_final, std_final, stats.num_vertices, stats.num_faces);

end

%% Helper Functions

function [V, F] = collapse_short_edges_simple(V, F, min_length)
    % Simplified edge collapse - merges vertices of short edges
    % For production: use proper edge collapse with topology preservation

    max_collapses_per_iteration = floor(size(V,1) * 0.1);  % Limit to 10% per pass
    num_collapsed = 0;

    % Build edge list
    edges = [F(:,[1,2]); F(:,[2,3]); F(:,[3,1])];
    edges = sort(edges, 2);
    edges = unique(edges, 'rows');

    % Compute edge lengths
    edge_lengths = sqrt(sum((V(edges(:,1),:) - V(edges(:,2),:)).^2, 2));

    % Find short edges
    short_edges = edges(edge_lengths < min_length, :);

    if isempty(short_edges)
        return;
    end

    % Collapse edges (merge second vertex into first)
    vertex_map = (1:size(V,1))';

    for i = 1:min(size(short_edges,1), max_collapses_per_iteration)
        v1 = short_edges(i,1);
        v2 = short_edges(i,2);

        % Merge v2 into v1 (place at midpoint)
        V(v1,:) = (V(v1,:) + V(v2,:)) / 2;

        % Update vertex map to redirect v2 to v1
        vertex_map(vertex_map == v2) = v1;

        num_collapsed = num_collapsed + 1;
    end

    % Update face indices
    F = vertex_map(F);

    % Clean up
    [V, F] = clean_mesh(V, F);
end

function V_smooth = laplacian_smooth_vertices(V, F, lambda)
    % Laplacian smoothing with damping factor lambda (0 to 1)

    num_vertices = size(V, 1);
    V_smooth = V;

    % Build adjacency list
    adjacency = cell(num_vertices, 1);
    for i = 1:size(F, 1)
        for j = 1:3
            v = F(i,j);
            neighbors = F(i, setdiff(1:3, j));
            adjacency{v} = [adjacency{v}; neighbors];
        end
    end

    % Remove duplicates
    for i = 1:num_vertices
        adjacency{i} = unique(adjacency{i});
    end

    % Smooth each vertex
    for i = 1:num_vertices
        if ~isempty(adjacency{i})
            neighbor_mean = mean(V(adjacency{i}, :), 1);
            V_smooth(i,:) = V(i,:) + lambda * (neighbor_mean - V(i,:));
        end
    end
end
