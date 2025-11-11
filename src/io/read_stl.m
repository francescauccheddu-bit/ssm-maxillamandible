function mesh = read_stl(filename)
% READ_STL Read STL file (ASCII or binary)
%
% Syntax:
%   mesh = read_stl(filename)
%
% Inputs:
%   filename - Path to STL file
%
% Outputs:
%   mesh - Struct with .vertices (Nx3) and .faces (Mx3)
%
% Example:
%   mesh = read_stl('model.stl');

    fid = fopen(filename, 'r');
    if fid == -1
        error('read_stl:FileNotFound', 'Cannot open file: %s', filename);
    end

    % Check if ASCII or binary
    first_line = fgetl(fid);
    fclose(fid);

    if contains(lower(first_line), 'solid')
        % Try ASCII format
        mesh = read_stl_ascii(filename);
    else
        % Binary format
        mesh = read_stl_binary(filename);
    end

    % Clean mesh
    [mesh.vertices, mesh.faces] = clean_mesh(mesh.vertices, mesh.faces);

end

function mesh = read_stl_ascii(filename)
    % Read ASCII STL file
    fid = fopen(filename, 'r');

    vertices = [];
    faces = [];
    vertex_count = 0;

    while ~feof(fid)
        line = fgetl(fid);
        if contains(line, 'vertex')
            % Parse vertex coordinates
            coords = sscanf(line, ' vertex %f %f %f');
            vertices = [vertices; coords'];
            vertex_count = vertex_count + 1;

            % Every 3 vertices form a face
            if mod(vertex_count, 3) == 0
                face_idx = vertex_count / 3;
                faces = [faces; (face_idx-1)*3+1, (face_idx-1)*3+2, (face_idx-1)*3+3];
            end
        end
    end

    fclose(fid);

    mesh.vertices = vertices;
    mesh.faces = faces;
end

function mesh = read_stl_binary(filename)
    % Read binary STL file
    fid = fopen(filename, 'r');

    % Skip header (80 bytes)
    fread(fid, 80, 'uint8');

    % Read number of triangles
    num_faces = fread(fid, 1, 'uint32');

    vertices = zeros(num_faces * 3, 3);
    faces = zeros(num_faces, 3);

    for i = 1:num_faces
        % Skip normal (3 floats)
        fread(fid, 3, 'float32');

        % Read vertices (3 vertices x 3 coordinates)
        v1 = fread(fid, 3, 'float32')';
        v2 = fread(fid, 3, 'float32')';
        v3 = fread(fid, 3, 'float32')';

        vertices((i-1)*3+1, :) = v1;
        vertices((i-1)*3+2, :) = v2;
        vertices((i-1)*3+3, :) = v3;

        faces(i, :) = [(i-1)*3+1, (i-1)*3+2, (i-1)*3+3];

        % Skip attribute byte count
        fread(fid, 1, 'uint16');
    end

    fclose(fid);

    mesh.vertices = vertices;
    mesh.faces = faces;
end
