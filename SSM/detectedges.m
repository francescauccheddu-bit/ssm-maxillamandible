function [Indices_edges] = detectedges(V, F)
% DETECTEDGES Detect free edges in a triangular mesh
%
% [Indices_edges] = detectedges(V, F)
%
% Detects free edges (edges that belong to only one face) in a mesh.
% A closed, manifold mesh should have no free edges.
%
% Input:
%   V - Vertices matrix (N x 3): [x, y, z] coordinates
%   F - Faces matrix (M x 3): vertex indices for each triangle
%
% Output:
%   Indices_edges - Indices of vertices that belong to free edges (empty if none)
%
% Author: Francesca Uccheddu, Università di Padova
% Date: 2025-11-04

% Get all edges from the mesh
edges = [F(:,1) F(:,2);
         F(:,2) F(:,3);
         F(:,3) F(:,1)];

% Sort each edge so that smaller vertex index comes first
edges = sort(edges, 2);

% Find unique edges and their counts
[unique_edges, ~, ic] = unique(edges, 'rows');

% Count occurrences of each edge
edge_counts = accumarray(ic, 1);

% Free edges are those that appear only once
free_edges_idx = find(edge_counts == 1);

if isempty(free_edges_idx)
    % No free edges found - mesh is closed
    Indices_edges = [];
else
    % Get the free edges
    free_edges = unique_edges(free_edges_idx, :);

    % Get all unique vertex indices that belong to free edges
    Indices_edges = unique(free_edges(:));
end

end
