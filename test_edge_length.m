function test_edge_length()
% TEST_EDGE_LENGTH Test remeshing with different edge lengths
%
% Tests a single specimen with multiple edge lengths to evaluate
% quality vs performance trade-off.
%
% Usage:
%   test_edge_length()

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  Edge Length Comparison Test\n');
    fprintf('========================================\n\n');

    % Add paths
    [script_dir, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(script_dir, 'src')));
    addpath(fullfile(script_dir, 'config'));

    % Load configuration
    config = pipeline_config();

    % Find first STL file
    stl_files = dir(fullfile(config.paths.training_female, '*.stl'));
    if isempty(stl_files)
        error('No STL files found in %s', config.paths.training_female);
    end

    test_file = fullfile(config.paths.training_female, stl_files(1).name);
    fprintf('Test specimen: %s\n\n', stl_files(1).name);

    % Edge lengths to test (prioritizing speed since no microdetails needed)
    edge_lengths = [3.0, 2.5, 2.0, 1.5];

    % Load original mesh
    fprintf('Loading original mesh...\n');
    [V_orig, F_orig] = read_stl(test_file);
    [V_orig, F_orig] = clean_mesh(V_orig, F_orig);

    % Original statistics
    edges_orig = [F_orig(:,[1,2]); F_orig(:,[2,3]); F_orig(:,[3,1])];
    edge_lengths_orig = sqrt(sum((V_orig(edges_orig(:,1),:) - V_orig(edges_orig(:,2),:)).^2, 2));

    fprintf('\n--- ORIGINAL MESH ---\n');
    fprintf('Vertices:    %d\n', size(V_orig, 1));
    fprintf('Faces:       %d\n', size(F_orig, 1));
    fprintf('Edge length: %.2f ± %.2f mm (min=%.2f, max=%.2f)\n\n', ...
        mean(edge_lengths_orig), std(edge_lengths_orig), ...
        min(edge_lengths_orig), max(edge_lengths_orig));

    % Test each edge length
    results = struct();

    for i = 1:length(edge_lengths)
        target_edge = edge_lengths(i);
        fprintf('========================================\n');
        fprintf('Testing edge_length = %.1f mm\n', target_edge);
        fprintf('========================================\n');

        % Center mesh (like normalize_mesh does)
        mesh.vertices = V_orig;
        mesh.faces = F_orig;
        centroid = mean(mesh.vertices, 1);
        mesh.vertices = mesh.vertices - centroid;

        % Remesh
        tic;
        [V_remesh, F_remesh, stats] = remesh_uniform(...
            mesh.vertices, mesh.faces, target_edge, 3);
        elapsed = toc;

        % Compute statistics
        edges = [F_remesh(:,[1,2]); F_remesh(:,[2,3]); F_remesh(:,[3,1])];
        edge_lens = sqrt(sum((V_remesh(edges(:,1),:) - V_remesh(edges(:,2),:)).^2, 2));

        % Store results
        results(i).target_edge = target_edge;
        results(i).num_vertices = size(V_remesh, 1);
        results(i).num_faces = size(F_remesh, 1);
        results(i).mean_edge = mean(edge_lens);
        results(i).std_edge = std(edge_lens);
        results(i).min_edge = min(edge_lens);
        results(i).max_edge = max(edge_lens);
        results(i).time = elapsed;

        % Display
        fprintf('Vertices:       %d (%.1fx reduction)\n', ...
            results(i).num_vertices, size(V_orig,1)/results(i).num_vertices);
        fprintf('Faces:          %d (%.1fx reduction)\n', ...
            results(i).num_faces, size(F_orig,1)/results(i).num_faces);
        fprintf('Actual edge:    %.2f ± %.2f mm (min=%.2f, max=%.2f)\n', ...
            results(i).mean_edge, results(i).std_edge, ...
            results(i).min_edge, results(i).max_edge);
        fprintf('Time:           %.1f seconds\n', results(i).time);
        fprintf('Target reached: %s (error: %.1f%%)\n', ...
            get_status(results(i).mean_edge, target_edge), ...
            abs(results(i).mean_edge - target_edge)/target_edge * 100);
        fprintf('\n');

        % Save mesh for inspection (optional)
        output_dir = 'output/edge_length_test';
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        output_file = fullfile(output_dir, sprintf('test_edge_%.1fmm.stl', target_edge));
        write_stl(output_file, V_remesh, F_remesh);
        fprintf('Saved: %s\n\n', output_file);
    end

    % Summary comparison
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  SUMMARY COMPARISON\n');
    fprintf('========================================\n\n');

    fprintf('%-12s | %-10s | %-10s | %-12s | %-8s\n', ...
        'Target (mm)', 'Vertices', 'Faces', 'Actual (mm)', 'Time (s)');
    fprintf('-------------+------------+------------+--------------+----------\n');
    for i = 1:length(results)
        fprintf('%-12.1f | %-10d | %-10d | %-12.2f | %-8.1f\n', ...
            results(i).target_edge, ...
            results(i).num_vertices, ...
            results(i).num_faces, ...
            results(i).mean_edge, ...
            results(i).time);
    end
    fprintf('\n');

    % Recommendations
    fprintf('========================================\n');
    fprintf('  RECOMMENDATIONS\n');
    fprintf('========================================\n\n');

    % Extrapolate to 20 specimens
    fprintf('For 20 specimens:\n\n');
    for i = 1:length(results)
        preprocessing_time = results(i).time * 20 / 60;  % minutes
        % Registration time scales with vertices^2 approximately
        registration_factor = (results(i).num_vertices / results(1).num_vertices)^1.5;
        total_estimate = preprocessing_time + (120 * registration_factor);  % 120min baseline

        fprintf('  %.1f mm: ~%.0f min preprocessing + ~%.0f min registration = ~%.0f min total (%.1f hours)\n', ...
            results(i).target_edge, preprocessing_time, 120*registration_factor, ...
            total_estimate, total_estimate/60);
    end

    fprintf('\n');
    fprintf('Since microdetails are NOT needed:\n');
    fprintf('  - FASTEST:   3.0mm (good for quick testing)\n');
    fprintf('  - BALANCED:  2.5mm (good quality, reasonable speed)\n');
    fprintf('  - SAFE:      2.0mm (if unsure about detail loss)\n');
    fprintf('  - DETAILED:  1.5mm (if you want to match paper exactly)\n');
    fprintf('\n');

    fprintf('Next steps:\n');
    fprintf('  1. Visually inspect meshes in output/edge_length_test/\n');
    fprintf('  2. Choose edge_length based on quality vs time trade-off\n');
    fprintf('  3. Update config/pipeline_config.m line 39:\n');
    fprintf('     config.preprocessing.edge_length = X.X;  %% Your choice\n');
    fprintf('\n');

end

function status = get_status(actual, target)
    error_pct = abs(actual - target) / target * 100;
    if error_pct < 10
        status = 'GOOD ✓';
    elseif error_pct < 20
        status = 'OK';
    else
        status = 'MISS';
    end
end
