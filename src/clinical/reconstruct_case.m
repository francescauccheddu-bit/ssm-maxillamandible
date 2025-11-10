function reconstruction = reconstruct_case(ssm_model, case_file, config)
% RECONSTRUCT_CASE Reconstruct damaged mandible using SSM
%
% Usage:
%   reconstruction = reconstruct_case(ssm_model, case_file, config)
%
% Parameters:
%   ssm_model - SSM model from build_ssm()
%   case_file - Path to damaged mandible STL file
%   config - Configuration with .clinical settings
%
% Returns:
%   reconstruction - Struct with reconstructed mesh and metrics

    logger(sprintf('=== Clinical Reconstruction: %s ===', case_file), 'level', 'INFO');

    % Load damaged mandible
    [V_damaged, F_damaged] = read_stl(case_file);
    logger(sprintf('Loaded damaged mandible: %d vertices, %d faces', ...
        size(V_damaged, 1), size(F_damaged, 1)));

    %% Step 1: Register damaged mandible to SSM space
    logger('Registering damaged mandible to SSM space...');

    % Center
    V_damaged_centered = V_damaged - mean(V_damaged, 1);

    % Rigid ICP alignment to mean shape
    mean_shape_vertices = ssm_model.mean_shape;
    [V_registered, ~] = rigid_icp(V_damaged_centered, mean_shape_vertices, config);

    logger('Registration complete');

    %% Step 2: Project onto principal components
    logger(sprintf('Projecting onto %d principal components...', config.clinical.num_pcs));

    % Vectorize registered shape
    registered_vec = V_registered(:);

    % Project onto PCs
    mean_shape_vec = ssm_model.mean_shape(:);
    residual = registered_vec - mean_shape_vec;
    eigenvectors = ssm_model.eigenvectors(:, 1:config.clinical.num_pcs);
    pc_scores = eigenvectors' * residual;

    logger(sprintf('PC scores: [%s]', sprintf('%.2f ', pc_scores')));

    %% Step 3: Reconstruct from SSM
    logger('Reconstructing shape from SSM...');

    reconstructed_mesh = reconstruct_from_ssm(ssm_model, pc_scores, 'num_pcs', config.clinical.num_pcs);

    %% Step 4: Compute metrics
    V_reconstructed = reconstructed_mesh.vertices;

    % Point-to-point distances (if same topology)
    if size(V_registered, 1) == size(V_reconstructed, 1)
        distances = sqrt(sum((V_registered - V_reconstructed).^2, 2));
        mean_dist = mean(distances);
        median_dist = median(distances);
        max_dist = max(distances);
        percentile_95 = prctile(distances, 95);
    else
        % Use nearest neighbor distances
        [~, distances] = knnsearch(V_reconstructed, V_registered);
        mean_dist = mean(distances);
        median_dist = median(distances);
        max_dist = max(distances);
        percentile_95 = prctile(distances, 95);
    end

    logger('Reconstruction metrics:');
    logger(sprintf('  Mean distance: %.2f mm', mean_dist));
    logger(sprintf('  Median distance: %.2f mm', median_dist));
    logger(sprintf('  Max distance: %.2f mm', max_dist));
    logger(sprintf('  95th percentile: %.2f mm', percentile_95));

    %% Step 5: Export results
    [~, case_name, ~] = fileparts(case_file);

    % Save reconstructed STL
    output_file = fullfile(config.paths.output.reconstructions, sprintf('reconstructed_%s.stl', case_name));
    write_stl(output_file, V_reconstructed, ssm_model.faces);
    logger(sprintf('Reconstructed mesh saved: %s', output_file));

    % Save registered damaged mesh
    registered_file = fullfile(config.paths.output.reconstructions, sprintf('registered_%s.stl', case_name));
    write_stl(registered_file, V_registered, F_damaged);
    logger(sprintf('Registered mesh saved: %s', registered_file));

    % Package results
    reconstruction.case_name = case_name;
    reconstruction.original_file = case_file;
    reconstruction.reconstructed_file = output_file;
    reconstruction.registered_file = registered_file;
    reconstruction.pc_scores = pc_scores;
    reconstruction.metrics.mean_distance = mean_dist;
    reconstruction.metrics.median_distance = median_dist;
    reconstruction.metrics.max_distance = max_dist;
    reconstruction.metrics.percentile_95 = percentile_95;

    logger('=== Reconstruction Complete ===');

end
