function [vertices_new, faces_new] = subdivide_large_edges(vertices, faces, max_edge_length)
% SUBDIVIDE_LARGE_EDGES Split edges longer than threshold
%
% Subdivides edges that are longer than the specified maximum length by
% adding a vertex at the midpoint and retriangulating.
%
% Syntax:
%   [V_new, F_new] = subdivide_large_edges(V, F, max_length)
%
% Inputs:
%   vertices       - Nx3 vertex matrix
%   faces          - Mx3 face matrix
%   max_edge_length - Maximum allowed edge length
%
% Outputs:
%   vertices_new - Extended vertex matrix with new midpoint vertices
%   faces_new    - Retriangulated faces
%
% Algorithm:
%   1. Find all edges longer than threshold
%   2. Add midpoint vertex for each long edge
%   3. Split triangles containing long edges into smaller triangles
%
% Note: This is a simplified version. For production use, consider
%       using loop subdivision or other advanced subdivision schemes.

    % Find long edges and split them iteratively
    max_iterations = 5;  % Prevent infinite loops

    vertices_new = vertices;
    faces_new = faces;

    for iter = 1:max_iterations
        % Compute all edge lengths
        v1 = faces_new(:,1);
        v2 = faces_new(:,2);
        v3 = faces_new(:,3);

        len_12 = sqrt(sum((vertices_new(v1,:) - vertices_new(v2,:)).^2, 2));
        len_13 = sqrt(sum((vertices_new(v1,:) - vertices_new(v3,:)).^2, 2));
        len_23 = sqrt(sum((vertices_new(v2,:) - vertices_new(v3,:)).^2, 2));

        % Find faces with at least one edge > threshold
        has_long_edge = (len_12 > max_edge_length) | ...
                        (len_13 > max_edge_length) | ...
                        (len_23 > max_edge_length);

        if ~any(has_long_edge)
            break;  % No more long edges
        end

        % Simple approach: Add midpoints for all edges of faces with long edges
        % (More sophisticated: only split specific long edges)

        faces_to_split = find(has_long_edge);
        num_new_vertices = length(faces_to_split) * 3;  % Worst case: 3 new vertices per face

        % Pre-allocate space for new vertices
        new_vertex_start = size(vertices_new, 1) + 1;
        vertices_new = [vertices_new; zeros(num_new_vertices, 3)];

        new_faces = [];
        keep_faces = true(size(faces_new, 1), 1);

        vertex_counter = new_vertex_start;

        for i = 1:length(faces_to_split)
            face_idx = faces_to_split(i);
            v1_idx = faces_new(face_idx, 1);
            v2_idx = faces_new(face_idx, 2);
            v3_idx = faces_new(face_idx, 3);

            % Add midpoint vertices
            mid_12 = (vertices_new(v1_idx,:) + vertices_new(v2_idx,:)) / 2;
            mid_13 = (vertices_new(v1_idx,:) + vertices_new(v3_idx,:)) / 2;
            mid_23 = (vertices_new(v2_idx,:) + vertices_new(v3_idx,:)) / 2;

            mid_12_idx = vertex_counter;
            mid_13_idx = vertex_counter + 1;
            mid_23_idx = vertex_counter + 2;

            vertices_new(mid_12_idx,:) = mid_12;
            vertices_new(mid_13_idx,:) = mid_13;
            vertices_new(mid_23_idx,:) = mid_23;

            vertex_counter = vertex_counter + 3;

            % Create 4 new triangles from subdivision
            new_faces = [new_faces;
                        v1_idx, mid_12_idx, mid_13_idx;
                        v2_idx, mid_23_idx, mid_12_idx;
                        v3_idx, mid_13_idx, mid_23_idx;
                        mid_12_idx, mid_23_idx, mid_13_idx];

            keep_faces(face_idx) = false;
        end

        % Update faces
        faces_new = [faces_new(keep_faces, :); new_faces];

        % Trim unused preallocated vertices
        vertices_new = vertices_new(1:vertex_counter-1, :);
    end

end
