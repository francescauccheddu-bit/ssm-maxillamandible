function write_stl(filename, vertices, faces, varargin)
% WRITE_STL Write mesh to STL file (binary format)
%
% Usage:
%   write_stl(filename, vertices, faces)
%   write_stl(filename, vertices, faces, 'format', 'ascii')
%
% Parameters:
%   filename - Output STL file path
%   vertices - Nx3 matrix of vertex coordinates
%   faces - Mx3 matrix of face indices (1-indexed)
%   'format' - 'binary' (default) or 'ascii'
%
% Example:
%   write_stl('output.stl', V, F);
%   write_stl('output.stl', V, F, 'format', 'ascii');

    p = inputParser;
    addRequired(p, 'filename', @ischar);
    addRequired(p, 'vertices', @isnumeric);
    addRequired(p, 'faces', @isnumeric);
    addParameter(p, 'format', 'binary', @(x) ismember(lower(x), {'binary', 'ascii'}));
    parse(p, filename, vertices, faces, varargin{:});

    format_type = lower(p.Results.format);

    % Validate inputs
    if size(vertices, 2) ~= 3
        error('write_stl:InvalidVertices', 'Vertices must be Nx3 matrix');
    end
    if size(faces, 2) ~= 3
        error('write_stl:InvalidFaces', 'Faces must be Mx3 matrix');
    end

    % Write based on format
    switch format_type
        case 'binary'
            write_stl_binary(filename, vertices, faces);
        case 'ascii'
            write_stl_ascii(filename, vertices, faces);
    end

end

function write_stl_binary(filename, vertices, faces)
    % Write binary STL file
    fid = fopen(filename, 'w');
    if fid == -1
        error('write_stl:CannotOpenFile', 'Cannot create file: %s', filename);
    end

    % Write header (80 bytes)
    header = sprintf('Binary STL created by MATLAB SSM Pipeline - %s', datestr(now));
    header = [header repmat(' ', 1, max(0, 80 - length(header)))];
    fwrite(fid, header(1:80), 'uint8');

    % Write number of triangles
    num_faces = size(faces, 1);
    fwrite(fid, num_faces, 'uint32');

    % Write each triangle
    for i = 1:num_faces
        % Get vertices of this face
        v1 = vertices(faces(i,1), :);
        v2 = vertices(faces(i,2), :);
        v3 = vertices(faces(i,3), :);

        % Calculate normal
        edge1 = v2 - v1;
        edge2 = v3 - v1;
        normal = cross(edge1, edge2);
        normal = normal / (norm(normal) + eps);

        % Write normal
        fwrite(fid, normal, 'float32');

        % Write vertices
        fwrite(fid, v1, 'float32');
        fwrite(fid, v2, 'float32');
        fwrite(fid, v3, 'float32');

        % Write attribute byte count (unused)
        fwrite(fid, 0, 'uint16');
    end

    fclose(fid);
end

function write_stl_ascii(filename, vertices, faces)
    % Write ASCII STL file
    fid = fopen(filename, 'w');
    if fid == -1
        error('write_stl:CannotOpenFile', 'Cannot create file: %s', filename);
    end

    % Write header
    fprintf(fid, 'solid mesh\n');

    % Write each triangle
    for i = 1:size(faces, 1)
        % Get vertices
        v1 = vertices(faces(i,1), :);
        v2 = vertices(faces(i,2), :);
        v3 = vertices(faces(i,3), :);

        % Calculate normal
        edge1 = v2 - v1;
        edge2 = v3 - v1;
        normal = cross(edge1, edge2);
        normal = normal / (norm(normal) + eps);

        % Write facet
        fprintf(fid, '  facet normal %e %e %e\n', normal(1), normal(2), normal(3));
        fprintf(fid, '    outer loop\n');
        fprintf(fid, '      vertex %e %e %e\n', v1(1), v1(2), v1(3));
        fprintf(fid, '      vertex %e %e %e\n', v2(1), v2(2), v2(3));
        fprintf(fid, '      vertex %e %e %e\n', v3(1), v3(2), v3(3));
        fprintf(fid, '    endloop\n');
        fprintf(fid, '  endfacet\n');
    end

    % Write footer
    fprintf(fid, 'endsolid mesh\n');

    fclose(fid);
end
