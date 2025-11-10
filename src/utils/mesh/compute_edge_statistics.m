function [mean_edge_length, std_edge_length] = compute_edge_statistics(vertices, faces)
% COMPUTE_EDGE_STATISTICS Calculate mean and standard deviation of edge lengths
%
% Computes statistics of all edges in a triangular mesh. Used to determine
% appropriate thresholds for remeshing operations.
%
% Syntax:
%   [mean_len, std_len] = compute_edge_statistics(vertices, faces)
%
% Inputs:
%   vertices - Nx3 matrix of vertex coordinates
%   faces    - Mx3 matrix of face indices
%
% Outputs:
%   mean_edge_length - Mean length of all edges in mesh
%   std_edge_length  - Standard deviation of edge lengths
%
% Example:
%   [V, F] = read_stl('mesh.stl');
%   [mean_len, std_len] = compute_edge_statistics(V, F);
%   fprintf('Edge length: %.2f ± %.2f mm\n', mean_len, std_len);
%
% Performance: O(M) where M is number of faces

    % Extract vertex indices for each edge of all triangles
    v1_indices = faces(:,1);
    v2_indices = faces(:,2);
    v3_indices = faces(:,3);

    % Compute edge lengths for all three edges of each triangle
    % Edge 1-2
    edge_12_lengths = sqrt(sum((vertices(v1_indices,:) - vertices(v2_indices,:)).^2, 2));

    % Edge 1-3
    edge_13_lengths = sqrt(sum((vertices(v1_indices,:) - vertices(v3_indices,:)).^2, 2));

    % Edge 2-3
    edge_23_lengths = sqrt(sum((vertices(v2_indices,:) - vertices(v3_indices,:)).^2, 2));

    % Concatenate all edge lengths
    all_edge_lengths = [edge_12_lengths; edge_13_lengths; edge_23_lengths];

    % Compute statistics
    mean_edge_length = mean(all_edge_lengths);
    std_edge_length = std(all_edge_lengths);

end
