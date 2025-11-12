function generate_pc_morphology_stls(ssm_model_path, output_dir, pcs_to_generate, std_multiplier)
% GENERATE_PC_MORPHOLOGY_STLS Genera file STL per visualizzare l'impatto morfologico dei PC
%
% Genera mesh STL per la forma media e le variazioni a ±N standard deviation
% per i principali componenti (PC1, PC2, PC3, etc.)
%
% Syntax:
%   generate_pc_morphology_stls(ssm_model_path, output_dir, pcs_to_generate, std_multiplier)
%
% Inputs:
%   ssm_model_path   - Percorso al file ssm_model.mat (default: 'output/ssm_model.mat')
%   output_dir       - Directory per salvare gli STL (default: 'output/pc_morphology')
%   pcs_to_generate  - Array dei PC da generare (default: [1, 2, 3])
%   std_multiplier   - Moltiplicatore per std deviation (default: 3)
%
% Output:
%   File STL per:
%   - mean_shape.stl (forma media)
%   - PC1_plus_3sd.stl, PC1_minus_3sd.stl
%   - PC2_plus_3sd.stl, PC2_minus_3sd.stl
%   - PC3_plus_3sd.stl, PC3_minus_3sd.stl
%
% Example:
%   generate_pc_morphology_stls('output/ssm_model.mat', 'output/pc_morphology', [1,2,3], 3)

    %% Default parameters
    if nargin < 1
        ssm_model_path = 'output/ssm_model.mat';
    end
    if nargin < 2
        output_dir = 'output/pc_morphology';
    end
    if nargin < 3
        pcs_to_generate = [1, 2, 3];
    end
    if nargin < 4
        std_multiplier = 3;
    end

    %% Load SSM model
    fprintf('========================================\n');
    fprintf('PC MORPHOLOGY STL GENERATION\n');
    fprintf('========================================\n');
    fprintf('Loading SSM model from: %s\n', ssm_model_path);
    load(ssm_model_path, 'ssm_model');

    %% Create output directory
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
        fprintf('Created output directory: %s\n', output_dir);
    end

    %% Extract model components
    mean_shape = ssm_model.mean_shape;
    shape_vectors = ssm_model.shape_vectors;
    eigenvalues = ssm_model.eigenvalues;
    faces = ssm_model.faces;
    num_vertices = ssm_model.num_vertices;
    variance_explained = ssm_model.variance_explained * 100;

    fprintf('\nModel info:\n');
    fprintf('  Vertices: %d\n', num_vertices);
    fprintf('  Faces: %d\n', size(faces, 1));
    fprintf('  Components: %d\n', ssm_model.num_components);

    %% Save mean shape
    fprintf('\n----------------------------------------\n');
    fprintf('Generating mean shape...\n');
    mean_stl_path = fullfile(output_dir, 'mean_shape.stl');
    write_stl_mesh(mean_stl_path, mean_shape, faces);
    fprintf('Saved: %s\n', mean_stl_path);

    %% Generate variations for each PC
    fprintf('\n----------------------------------------\n');
    fprintf('Generating PC variations at ±%dSD...\n', std_multiplier);
    fprintf('----------------------------------------\n');

    for pc_idx = pcs_to_generate
        if pc_idx > ssm_model.num_components
            warning('PC%d exceeds available components (%d). Skipping.', ...
                pc_idx, ssm_model.num_components);
            continue;
        end

        fprintf('\n[PC%d] Variance explained: %.2f%%\n', pc_idx, variance_explained(pc_idx));

        % Get shape vector for this PC
        shape_vec = shape_vectors(:, pc_idx);

        % Compute standard deviation for this PC
        % std = sqrt(eigenvalue)
        pc_std = sqrt(eigenvalues(pc_idx));

        fprintf('  Eigenvalue: %.6f\n', eigenvalues(pc_idx));
        fprintf('  Std deviation: %.6f\n', pc_std);

        % Compute variations
        delta = std_multiplier * pc_std;

        % Plus variation (mean + delta * shape_vector)
        mean_vec = mean_shape(:);  % Flatten to column vector
        shape_vec_reshaped = reshape(shape_vec, num_vertices, 3);

        plus_shape = mean_shape + std_multiplier * pc_std * shape_vec_reshaped;
        minus_shape = mean_shape - std_multiplier * pc_std * shape_vec_reshaped;

        % Save STL files
        plus_stl_path = fullfile(output_dir, sprintf('PC%d_plus_%dsd.stl', pc_idx, std_multiplier));
        minus_stl_path = fullfile(output_dir, sprintf('PC%d_minus_%dsd.stl', pc_idx, std_multiplier));

        write_stl_mesh(plus_stl_path, plus_shape, faces);
        write_stl_mesh(minus_stl_path, minus_shape, faces);

        fprintf('  Saved: %s\n', plus_stl_path);
        fprintf('  Saved: %s\n', minus_stl_path);

        % Compute morphological changes (max distance from mean)
        plus_distances = vecnorm(plus_shape - mean_shape, 2, 2);
        minus_distances = vecnorm(minus_shape - mean_shape, 2, 2);

        fprintf('  Max morphological change (+): %.3f mm\n', max(plus_distances));
        fprintf('  Max morphological change (-): %.3f mm\n', max(minus_distances));
        fprintf('  Mean morphological change (+): %.3f mm\n', mean(plus_distances));
        fprintf('  Mean morphological change (-): %.3f mm\n', mean(minus_distances));
    end

    %% Create summary file
    fprintf('\n----------------------------------------\n');
    summary_file = fullfile(output_dir, 'generation_summary.txt');
    fid = fopen(summary_file, 'w');

    fprintf(fid, '========================================\n');
    fprintf(fid, 'PC MORPHOLOGY STL GENERATION SUMMARY\n');
    fprintf(fid, '========================================\n');
    fprintf(fid, 'Date: %s\n', datestr(now));
    fprintf(fid, 'SSM model: %s\n', ssm_model_path);
    fprintf(fid, 'Output directory: %s\n', output_dir);
    fprintf(fid, '\nParameters:\n');
    fprintf(fid, '  PCs generated: %s\n', mat2str(pcs_to_generate));
    fprintf(fid, '  Std multiplier: %d\n', std_multiplier);
    fprintf(fid, '\nModel info:\n');
    fprintf(fid, '  Vertices: %d\n', num_vertices);
    fprintf(fid, '  Faces: %d\n', size(faces, 1));
    fprintf(fid, '  Total components: %d\n', ssm_model.num_components);

    fprintf(fid, '\nFiles generated:\n');
    fprintf(fid, '  - mean_shape.stl\n');
    for pc_idx = pcs_to_generate
        if pc_idx <= ssm_model.num_components
            fprintf(fid, '  - PC%d_plus_%dsd.stl (variance: %.2f%%)\n', ...
                pc_idx, std_multiplier, variance_explained(pc_idx));
            fprintf(fid, '  - PC%d_minus_%dsd.stl (variance: %.2f%%)\n', ...
                pc_idx, std_multiplier, variance_explained(pc_idx));
        end
    end

    fprintf(fid, '\n========================================\n');
    fclose(fid);

    fprintf('Summary saved: %s\n', summary_file);

    %% Final message
    fprintf('\n========================================\n');
    fprintf('[OK] STL generation completed!\n');
    fprintf('Files saved to: %s\n', output_dir);
    fprintf('========================================\n\n');

end


%% Helper function to write STL mesh
function write_stl_mesh(filename, vertices, faces)
    % WRITE_STL_MESH Scrive un file STL in formato ASCII
    %
    % Inputs:
    %   filename - Percorso del file STL da creare
    %   vertices - Matrix Nx3 dei vertici
    %   faces    - Matrix Mx3 delle facce (indices)

    fid = fopen(filename, 'w');
    if fid == -1
        error('Cannot open file: %s', filename);
    end

    % Write header
    fprintf(fid, 'solid mesh\n');

    % Write each triangle
    for i = 1:size(faces, 1)
        % Get vertices of this face
        v1 = vertices(faces(i, 1), :);
        v2 = vertices(faces(i, 2), :);
        v3 = vertices(faces(i, 3), :);

        % Compute normal
        edge1 = v2 - v1;
        edge2 = v3 - v1;
        normal = cross(edge1, edge2);
        normal = normal / (norm(normal) + eps);  % Normalize

        % Write facet
        fprintf(fid, '  facet normal %.6e %.6e %.6e\n', normal(1), normal(2), normal(3));
        fprintf(fid, '    outer loop\n');
        fprintf(fid, '      vertex %.6e %.6e %.6e\n', v1(1), v1(2), v1(3));
        fprintf(fid, '      vertex %.6e %.6e %.6e\n', v2(1), v2(2), v2(3));
        fprintf(fid, '      vertex %.6e %.6e %.6e\n', v3(1), v3(2), v3(3));
        fprintf(fid, '    endloop\n');
        fprintf(fid, '  endfacet\n');
    end

    % Write footer
    fprintf(fid, 'endsolid mesh\n');
    fclose(fid);
end
