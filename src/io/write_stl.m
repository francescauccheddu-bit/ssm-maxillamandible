function write_stl(filename, vertices, faces)
% WRITE_STL Write mesh to STL file (ASCII format)
%
% Syntax:
%   write_stl(filename, vertices, faces)
%
% Inputs:
%   filename - Output STL file path
%   vertices - Nx3 vertex matrix
%   faces    - Mx3 face matrix
%
% Example:
%   write_stl('output.stl', V, F);

    % Open file
    fid = fopen(filename, 'w');
    if fid == -1
        error('write_stl:FileOpenError', 'Cannot open file: %s', filename);
    end

    % Write header
    fprintf(fid, 'solid mesh\n');

    % Write each triangle
    for i = 1:size(faces, 1)
        % Get triangle vertices
        v1 = vertices(faces(i,1), :);
        v2 = vertices(faces(i,2), :);
        v3 = vertices(faces(i,3), :);

        % Compute normal
        edge1 = v2 - v1;
        edge2 = v3 - v1;
        normal = cross(edge1, edge2);
        normal = normal / norm(normal);

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

    % Close file
    fclose(fid);

end
