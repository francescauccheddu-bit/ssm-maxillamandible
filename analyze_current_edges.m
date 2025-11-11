function analyze_current_edges()
% ANALYZE_CURRENT_EDGES Calculate edge statistics from current meshes
%
% This script analyzes the edge length distribution of the reduced meshes
% to determine what edge_length value should be used in the config.

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  Current Mesh Edge Analysis\n');
    fprintf('========================================\n\n');

    % Path to your mesh files (MODIFY THIS for Windows)
    mesh_dir = 'C:\FRANCESCAdocs\unipd\COLLABORAZIONI\IADANZA DENTI\CODICE MATLAB SSM\data\training\female';

    % Get all STL files
    stl_files = dir(fullfile(mesh_dir, '*.stl'));

    if isempty(stl_files)
        error('No STL files found in %s', mesh_dir);
    end

    fprintf('Found %d mesh files\n', length(stl_files));
    fprintf('Analyzing first 5 files...\n\n');

    % Analyze first 5 files to get statistics
    num_to_analyze = min(5, length(stl_files));
    all_stats = struct();

    for i = 1:num_to_analyze
        filepath = fullfile(mesh_dir, stl_files(i).name);
        fprintf('File %d/%d: %s\n', i, num_to_analyze, stl_files(i).name);

        % Read STL file
        [V, F] = read_stl_simple(filepath);

        % Calculate edge statistics
        edges = [F(:,[1,2]); F(:,[2,3]); F(:,[3,1])];
        edge_vectors = V(edges(:,1),:) - V(edges(:,2),:);
        edge_lengths = sqrt(sum(edge_vectors.^2, 2));

        % Store statistics
        all_stats(i).filename = stl_files(i).name;
        all_stats(i).num_vertices = size(V, 1);
        all_stats(i).num_faces = size(F, 1);
        all_stats(i).mean_edge = mean(edge_lengths);
        all_stats(i).std_edge = std(edge_lengths);
        all_stats(i).min_edge = min(edge_lengths);
        all_stats(i).max_edge = max(edge_lengths);
        all_stats(i).median_edge = median(edge_lengths);

        fprintf('  Vertices: %d\n', all_stats(i).num_vertices);
        fprintf('  Faces:    %d\n', all_stats(i).num_faces);
        fprintf('  Edge length: %.3f ± %.3f mm (range: %.3f - %.3f mm)\n', ...
            all_stats(i).mean_edge, all_stats(i).std_edge, ...
            all_stats(i).min_edge, all_stats(i).max_edge);
        fprintf('  Median edge: %.3f mm\n\n', all_stats(i).median_edge);
    end

    % Overall statistics
    fprintf('========================================\n');
    fprintf('OVERALL STATISTICS (across %d files)\n', num_to_analyze);
    fprintf('========================================\n');

    all_means = [all_stats.mean_edge];
    all_medians = [all_stats.median_edge];
    all_faces = [all_stats.num_faces];

    fprintf('Average vertices:    %d\n', round(mean([all_stats.num_vertices])));
    fprintf('Average faces:       %d\n', round(mean(all_faces)));
    fprintf('Mean edge length:    %.3f mm (± %.3f mm across files)\n', ...
        mean(all_means), std(all_means));
    fprintf('Median edge length:  %.3f mm\n', mean(all_medians));
    fprintf('\n');

    % Recommendation
    recommended_edge = round(mean(all_means) * 10) / 10;  % Round to 0.1mm

    fprintf('========================================\n');
    fprintf('RECOMMENDATION\n');
    fprintf('========================================\n');
    fprintf('Based on the analysis of your reduced meshes:\n\n');
    fprintf('Recommended config.preprocessing.edge_length = %.1f mm\n\n', recommended_edge);
    fprintf('This value represents the average edge length in your\n');
    fprintf('current meshes (approximately %d triangles per mesh).\n\n', round(mean(all_faces)));

    % Distribution analysis
    fprintf('Edge length distribution details:\n');
    for i = 1:num_to_analyze
        ratio = all_stats(i).max_edge / all_stats(i).min_edge;
        fprintf('  %s: ratio max/min = %.2f\n', all_stats(i).filename, ratio);
    end
    fprintf('\n');

    fprintf('If you want to enable remeshing in the future, use:\n');
    fprintf('  config.preprocessing.enable_remeshing = true;\n');
    fprintf('  config.preprocessing.edge_length = %.1f;\n', recommended_edge);
    fprintf('\n');

end

function [vertices, faces] = read_stl_simple(filename)
% READ_STL_SIMPLE Simple STL reader (binary format)
%
% Simplified version that works without external dependencies

    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end

    % Read header (80 bytes)
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
        faces(i, :) = [idx, idx+1, idx+2];

        % Skip attribute (2 bytes)
        fread(fid, 1, 'uint16');
    end

    fclose(fid);

    % Remove duplicate vertices (optional, for accurate count)
    [vertices, ~, idx] = unique(vertices, 'rows', 'stable');
    faces = idx(faces);
end