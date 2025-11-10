function [vertices, faces] = read_stl(filename)
% READ_STL Read STL file (ASCII or binary)
%
% Usage:
%   [vertices, faces] = read_stl(filename)
%
% Parameters:
%   filename - Path to STL file
%
% Returns:
%   vertices - Nx3 matrix of vertex coordinates
%   faces - Mx3 matrix of face indices (1-indexed)
%
% Example:
%   [V, F] = read_stl('mandible.stl');

    % Validate input
    if ~exist(filename, 'file')
        error('read_stl:FileNotFound', 'File does not exist: %s', filename);
    end

    % Open file
    fid = fopen(filename, 'r');
    if fid == -1
        error('read_stl:CannotOpenFile', 'Cannot open file: %s', filename);
    end

    % Read first line to determine format
    first_line = fgetl(fid);
    fclose(fid);

    % Check if ASCII (starts with 'solid')
    if contains(lower(first_line), 'solid')
        [vertices, faces] = read_stl_ascii(filename);
    else
        [vertices, faces] = read_stl_binary(filename);
    end

end

function [vertices, faces] = read_stl_ascii(filename)
    % Read ASCII STL file
    fid = fopen(filename, 'r');

    % Skip 'solid' line
    fgetl(fid);

    vertices = [];
    faces = [];
    vertex_count = 0;
    face_vertices = [];

    while ~feof(fid)
        line = strtrim(fgetl(fid));

        if contains(line, 'vertex')
            % Extract coordinates
            coords = sscanf(line, 'vertex %f %f %f');
            vertex_count = vertex_count + 1;
            vertices = [vertices; coords'];
            face_vertices = [face_vertices; vertex_count];

            % Every 3 vertices form a face
            if mod(vertex_count, 3) == 0
                faces = [faces; face_vertices'];
                face_vertices = [];
            end
        end
    end

    fclose(fid);
end

function [vertices, faces] = read_stl_binary(filename)
    % Read binary STL file
    fid = fopen(filename, 'r');

    % Skip header (80 bytes)
    fread(fid, 80, 'uint8');

    % Read number of triangles
    num_faces = fread(fid, 1, 'uint32');

    % Preallocate
    vertices = zeros(num_faces * 3, 3);
    faces = zeros(num_faces, 3);

    % Read each triangle
    for i = 1:num_faces
        % Skip normal (3 floats)
        fread(fid, 3, 'float32');

        % Read 3 vertices
        v1 = fread(fid, 3, 'float32')';
        v2 = fread(fid, 3, 'float32')';
        v3 = fread(fid, 3, 'float32')';

        % Store vertices
        idx = (i-1)*3 + 1;
        vertices(idx:idx+2, :) = [v1; v2; v3];

        % Store face
        faces(i, :) = [idx, idx+1, idx+2];

        % Skip attribute byte count
        fread(fid, 1, 'uint16');
    end

    fclose(fid);
end
