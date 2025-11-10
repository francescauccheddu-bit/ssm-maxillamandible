function free_vertex_indices = detect_free_edges(vertices, faces)
% DETECT_FREE_EDGES Find vertices on free edges (mesh boundaries)
%
% Free edges are edges that belong to only one triangle. In a closed,
% manifold mesh, there should be no free edges. Free edges indicate
% boundaries or holes in the mesh.
%
% Syntax:
%   free_vertex_indices = detect_free_edges(vertices, faces)
%
% Inputs:
%   vertices - Nx3 matrix of vertex coordinates [x, y, z]
%   faces    - Mx3 matrix of face indices (1-indexed triangles)
%
% Outputs:
%   free_vertex_indices - Column vector of vertex indices on free edges
%                         Empty array [] if mesh is closed
%
% Example:
%   [V, F] = read_stl('mandible.stl');
%   free_verts = detect_free_edges(V, F);
%   if isempty(free_verts)
%       fprintf('Mesh is closed (no boundaries)\n');
%   else
%       fprintf('Found %d vertices on boundaries\n', length(free_verts));
%   end
%
% Algorithm:
%   1. Extract all edges from triangular faces
%   2. Normalize edge representation (smaller index first)
%   3. Count occurrences of each edge
%   4. Identify edges that appear exactly once (free edges)
%   5. Return unique vertex indices from free edges
%
% Performance: O(M) where M is number of faces
%
% See also: clean_mesh, remove_degenerate_faces

    % Input validation
    if nargin < 2
        error('detect_free_edges:NotEnoughInputs', ...
            'Both vertices and faces required');
    end

    if size(faces, 2) ~= 3
        error('detect_free_edges:InvalidFaces', ...
            'Faces must be Mx3 matrix (triangular mesh)');
    end

    % Extract all edges from faces (each triangle has 3 edges)
    % Edge (v1,v2), (v2,v3), (v3,v1)
    all_edges = [faces(:,1), faces(:,2);  % Edge 1-2
                 faces(:,2), faces(:,3);  % Edge 2-3
                 faces(:,3), faces(:,1)]; % Edge 3-1

    % Normalize edge representation: sort vertices so smaller index comes first
    % This ensures edge (i,j) and (j,i) are treated as the same edge
    all_edges_sorted = sort(all_edges, 2);

    % Find unique edges and count their occurrences
    [unique_edges, ~, edge_ids] = unique(all_edges_sorted, 'rows', 'stable');

    % Count how many times each unique edge appears
    % In a manifold mesh:
    %   - Interior edges appear exactly 2 times (shared by 2 triangles)
    %   - Boundary edges appear exactly 1 time (belong to 1 triangle)
    edge_counts = accumarray(edge_ids, 1);

    % Find free edges (those appearing only once)
    is_free_edge = (edge_counts == 1);

    if ~any(is_free_edge)
        % Closed mesh - no boundaries
        free_vertex_indices = [];
        return;
    end

    % Extract free edges
    free_edges = unique_edges(is_free_edge, :);

    % Get all unique vertex indices that belong to free edges
    free_vertex_indices = unique(free_edges(:));

    % Ensure column vector output
    free_vertex_indices = free_vertex_indices(:);

end
