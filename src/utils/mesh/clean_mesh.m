function [vertices_clean, faces_clean] = clean_mesh(vertices, faces)
% CLEAN_MESH Remove duplicate vertices, degenerate faces, and orphaned vertices
%
% Performs comprehensive mesh cleanup:
%   1. Removes duplicate vertices (keeps first occurrence)
%   2. Updates face indices to reference unique vertices
%   3. Removes degenerate faces (triangles with repeated vertex indices)
%   4. Removes orphaned vertices (not referenced by any face)
%   5. Reindexes vertices to be contiguous
%
% Syntax:
%   [vertices_clean, faces_clean] = clean_mesh(vertices, faces)
%
% Inputs:
%   vertices - Nx3 matrix of vertex coordinates
%   faces    - Mx3 matrix of face indices (1-indexed)
%
% Outputs:
%   vertices_clean - Cleaned vertex matrix (may have fewer rows)
%   faces_clean    - Cleaned face matrix with updated indices
%
% Example:
%   [V, F] = read_stl('mesh.stl');
%   [V_clean, F_clean] = clean_mesh(V, F);
%   fprintf('Removed %d duplicate/orphaned vertices\n', size(V,1) - size(V_clean,1));
%   fprintf('Removed %d degenerate faces\n', size(F,1) - size(F_clean,1));
%
% See also: remove_degenerate_faces, detect_free_edges

    % Input validation
    if nargin < 2
        error('clean_mesh:NotEnoughInputs', 'Both vertices and faces required');
    end

    %% Step 1: Remove duplicate vertices
    [vertices_unique, ~, vertex_map] = unique(vertices, 'rows', 'stable');

    % Update face indices to point to unique vertices
    faces_updated = vertex_map(faces);

    %% Step 2: Remove degenerate faces
    % Degenerate faces have repeated vertices (e.g., [1,1,2] or [1,2,1])
    % These occur when two or more vertices of a triangle are the same

    % Check each edge of the triangle for equality
    edge1_degenerate = (faces_updated(:,1) == faces_updated(:,2));
    edge2_degenerate = (faces_updated(:,2) == faces_updated(:,3));
    edge3_degenerate = (faces_updated(:,3) == faces_updated(:,1));

    % A face is degenerate if any edge has equal vertices
    is_degenerate = edge1_degenerate | edge2_degenerate | edge3_degenerate;

    % Keep only valid faces
    faces_valid = faces_updated(~is_degenerate, :);

    %% Step 3: Remove orphaned vertices (not referenced by any face)
    % Find which vertices are actually used by faces
    vertices_used = unique(faces_valid(:));

    % Create mapping from old indices to new contiguous indices
    num_vertices_unique = size(vertices_unique, 1);
    vertex_is_used = false(num_vertices_unique, 1);
    vertex_is_used(vertices_used) = true;

    % New contiguous indices for used vertices
    new_vertex_indices = zeros(num_vertices_unique, 1);
    new_vertex_indices(vertex_is_used) = 1:sum(vertex_is_used);

    % Extract only used vertices
    vertices_clean = vertices_unique(vertex_is_used, :);

    % Update face indices to new vertex numbering
    faces_clean = new_vertex_indices(faces_valid);

    %% Validation of output
    % Ensure all face indices are valid
    assert(all(faces_clean(:) > 0) && all(faces_clean(:) <= size(vertices_clean, 1)), ...
        'clean_mesh:InvalidOutput', 'Face indices out of range after cleaning');

    % Ensure no degenerate faces remain
    assert(~any(faces_clean(:,1) == faces_clean(:,2) | ...
                faces_clean(:,2) == faces_clean(:,3) | ...
                faces_clean(:,3) == faces_clean(:,1)), ...
        'clean_mesh:DegenerateFacesRemain', 'Degenerate faces still present after cleaning');

end
