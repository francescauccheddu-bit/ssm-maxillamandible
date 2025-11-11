function run_pipeline(varargin)
% RUN_PIPELINE Main entry point for SSM pipeline
%
% Usage:
%   run_pipeline                    % Run with default configuration
%   run_pipeline('config', cfg)     % Run with custom configuration
%   run_pipeline('start_from', 3)   % Resume from phase 3
%   run_pipeline('only', 2)         % Run only phase 2
%
% Parameters:
%   'config' - Custom configuration struct
%   'start_from' - Phase number to start from (1-5)
%   'only' - Run only specified phase
%   'force' - Force recomputation (ignore checkpoints)
%
% Phases:
%   1. Preprocessing - Load and prepare meshes
%   2. Registration - Align all meshes
%   3. SSM Building - Compute PCA-based model
%   4. Analysis - Statistical sex difference testing
%   5. Reconstruction - Clinical case reconstruction

    %% Add Paths (must be done BEFORE loading config)
    [pipeline_dir, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(pipeline_dir, 'src')));
    addpath(fullfile(pipeline_dir, 'config'));

    %% Parse Input
    p = inputParser;
    addParameter(p, 'config', [], @(x) isempty(x) || isstruct(x));
    addParameter(p, 'start_from', 1, @isnumeric);
    addParameter(p, 'only', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'force', false, @islogical);
    parse(p, varargin{:});

    % Load configuration
    if isempty(p.Results.config)
        config = pipeline_config();
    else
        config = p.Results.config;
    end

    % Override with command-line arguments
    if p.Results.force
        config.execution.force_recompute = true;
    end
    if ~isempty(p.Results.start_from)
        config.execution.start_from_phase = p.Results.start_from;
    end
    if ~isempty(p.Results.only)
        config.execution.run_only_phase = p.Results.only;
    end

    %% Initialize Logging
    if config.logging.enabled
        log_file = fullfile(config.logging.log_dir, ...
            sprintf('pipeline_log_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
        diary(log_file);
    end

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  SSM Pipeline for Maxilla/Mandible\n');
    fprintf('========================================\n');
    logger(sprintf('Started: %s', datestr(now)), 'level', 'INFO');
    fprintf('Log file: %s\n\n', log_file);

    % Start global timer
    pipeline_start_time = tic;

    %% Display Configuration
    display_config(config);

    %% Define Phases
    phases = {
        'Preprocessing', @phase_preprocessing;
        'Registration', @phase_registration;
        'SSM Building', @phase_ssm_building;
        'Statistical Analysis', @phase_analysis;
        'Clinical Reconstruction', @phase_reconstruction;
    };

    % Determine which phases to run
    if ~isempty(config.execution.run_only_phase)
        phase_indices = config.execution.run_only_phase;
    else
        phase_indices = config.execution.start_from_phase:length(phases);
    end

    %% Execute Pipeline
    results = struct();
    success = true;

    for i = phase_indices
        phase_name = phases{i, 1};
        phase_func = phases{i, 2};

        fprintf('\n');
        fprintf('========================================\n');
        fprintf('PHASE %d: %s\n', i, upper(phase_name));
        fprintf('========================================\n');

        % Start phase timer
        phase_start_time = tic;

        try
            % Check checkpoint
            if config.checkpoint.enabled && ~config.execution.force_recompute
                checkpoint_file = get_checkpoint_file(config, i);
                if exist(checkpoint_file, 'file')
                    logger(sprintf('Loading checkpoint: %s', checkpoint_file));
                    checkpoint_data = load(checkpoint_file);
                    results = merge_structs(results, checkpoint_data.results);
                    logger('Phase skipped (checkpoint loaded)');
                    continue;
                end
            end

            % Execute phase
            phase_results = phase_func(config, results);
            phase_elapsed = toc(phase_start_time);

            logger(sprintf('Phase %d completed in %.1f seconds (%.1f min)', ...
                i, phase_elapsed, phase_elapsed/60), 'level', 'INFO');

            % Merge results
            results = merge_structs(results, phase_results);

            % Save checkpoint
            if config.checkpoint.enabled
                checkpoint_file = get_checkpoint_file(config, i);
                save(checkpoint_file, 'results', 'config', '-v7.3');
                logger(sprintf('Checkpoint saved: %s', checkpoint_file));
            end

        catch ME
            logger(sprintf('ERROR in Phase %d: %s', i, phase_name), 'level', 'ERROR');
            logger(sprintf('Message: %s', ME.message), 'level', 'ERROR');
            logger(sprintf('Location: %s (line %d)', ME.stack(1).name, ME.stack(1).line), 'level', 'ERROR');
            success = false;
            break;
        end
    end

    %% Summary
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('PIPELINE SUMMARY\n');
    fprintf('========================================\n');

    if success
        fprintf('Status: SUCCESS\n\n');

        if isfield(results, 'ssm_model')
            fprintf('SSM Model: %s\n', config.paths.output.ssm_model);
            fprintf('  - Specimens: %d\n', results.ssm_model.num_specimens);
            fprintf('  - Vertices: %d\n', results.ssm_model.num_vertices);
            fprintf('  - Components: %d\n', results.ssm_model.num_components);
        end

        if isfield(results, 'analysis_results')
            fprintf('\nStatistical Analysis:\n');
            fprintf('  - Significant PCs: %d\n', sum(results.analysis_results.significant));
        end

        if isfield(results, 'reconstructions')
            fprintf('\nClinical Reconstructions: %d cases\n', length(results.reconstructions));
        end
    else
        fprintf('Status: FAILED\n');
        fprintf('Pipeline terminated due to error\n');
    end

    % Total pipeline time
    total_elapsed = toc(pipeline_start_time);
    fprintf('\nFinished: %s\n', datestr(now));
    fprintf('Total time: %.1f seconds (%.1f min, %.2f hours)\n', ...
        total_elapsed, total_elapsed/60, total_elapsed/3600);
    fprintf('========================================\n\n');

    %% Cleanup
    if config.logging.enabled
        diary off;
    end

end

%% Phase Implementation Functions

function results = phase_preprocessing(config, ~)
    % Phase 1: Load and preprocess training data
    logger('Loading training data...', 'level', 'INFO');

    % Load STL files
    [meshes, metadata] = load_training_data(config);

    % Store original scales BEFORE normalization (for rescaling after registration)
    logger('Computing original scales...');
    original_scales = zeros(length(meshes), 1);
    for i = 1:length(meshes)
        % Compute RMS distance from centroid as scale measure
        centroid = mean(meshes{i}.vertices, 1);
        distances = sqrt(sum((meshes{i}.vertices - centroid).^2, 2));
        original_scales(i) = sqrt(mean(distances.^2));
    end

    % Normalize meshes
    logger('Normalizing meshes...');
    for i = 1:length(meshes)
        meshes{i} = normalize_mesh(meshes{i}, config);
    end

    % Remesh (optional)
    if config.preprocessing.remesh_enabled
        logger('Remeshing meshes...');
        for i = 1:length(meshes)
            progress_bar(i, length(meshes), 'message', 'Remeshing');
            [meshes{i}.vertices, meshes{i}.faces, ~] = remesh_uniform(...
                meshes{i}.vertices, meshes{i}.faces, ...
                config.preprocessing.edge_length, ...
                config.preprocessing.remesh_iterations);
        end
    end

    results.meshes = meshes;
    results.metadata = metadata;
    results.original_scales = original_scales;  % Store for later rescaling

end

function results = phase_registration(config, prev_results)
    % Phase 2: Register all meshes
    logger('Registering meshes...', 'level', 'INFO');

    meshes = prev_results.meshes;

    % Template selection (per paper section 2.4)
    if isfield(config.registration, 'template_index') && ~isempty(config.registration.template_index)
        % Use specified template
        template_idx = config.registration.template_index;
        logger(sprintf('Using specified template: specimen %d', template_idx), 'level', 'INFO');
    else
        % Auto-select: find specimen closest to preliminary mean shape
        logger('Selecting optimal template (closest to preliminary mean)...');
        template_idx = select_template_closest_to_mean(meshes);
        logger(sprintf('Auto-selected specimen %d as template', template_idx), 'level', 'INFO');
        logger(sprintf('TIP: To skip template search next time, set config.registration.template_index = %d', template_idx), 'level', 'INFO');
    end

    % Iterative registration (3 iterations per paper)
    num_iterations = 3;
    if isfield(config.registration, 'num_iterations')
        num_iterations = config.registration.num_iterations;
    end

    for iter = 1:num_iterations
        logger(sprintf('Phase 2 - Iteration %d/%d:', iter, num_iterations));

        % Current template
        template_vertices = meshes{template_idx}.vertices;
        template_faces = meshes{template_idx}.faces;

        % 2a: Rigid ICP (affine registration)
        logger(sprintf('  Rigid ICP alignment (iteration %d)...', iter));
        rigid_opts.use_prealignment = (iter == 1);  % Only first iteration
        rigid_opts.max_iterations = config.registration.rigid_icp.iterations;

        for i = 1:length(meshes)
            if i == template_idx
                continue;  % Template doesn't need alignment
            end
            progress_bar(i, length(meshes), 'message', sprintf('Rigid ICP iter %d', iter));

            [meshes{i}.vertices, ~] = rigid_icp_full(...
                meshes{i}.vertices, template_vertices, rigid_opts);
        end

        % 2b: Non-rigid ICP
        if config.registration.use_nonrigid
            logger(sprintf('  Non-rigid ICP alignment (iteration %d)...', iter));
            nonrigid_opts.iterations = config.registration.nonrigid_icp.iterations;
            nonrigid_opts.lambda = config.registration.nonrigid_icp.lambda;
            nonrigid_opts.use_rigid_prealign = false;  % Already aligned

            for i = 1:length(meshes)
                if i == template_idx
                    continue;
                end
                progress_bar(i, length(meshes), 'message', sprintf('Non-rigid ICP iter %d', iter));

                [meshes{i}.vertices, ~] = nonrigid_icp_rbf(...
                    meshes{i}.vertices, meshes{i}.faces, ...
                    template_vertices, template_faces, nonrigid_opts);
            end
        end

        % Update template to mean shape for next iteration
        if iter < num_iterations
            logger(sprintf('  Updating template to mean shape...', iter), 'level', 'DEBUG');
            % Compute mean shape (centered)
            mean_vertices = zeros(size(meshes{1}.vertices));
            for i = 1:length(meshes)
                centroid = mean(meshes{i}.vertices, 1);
                mean_vertices = mean_vertices + (meshes{i}.vertices - centroid);
            end
            mean_vertices = mean_vertices / length(meshes);

            % Find closest mesh to new mean
            template_idx = select_template_closest_to_mean(meshes);
        end
    end

    % Rescale to original size (per paper section 2.4)
    % After affine+nonrigid registration, restore anatomical scale
    if isfield(prev_results, 'original_scales')
        logger('Phase 2c: Rescaling to original anatomical size...');
        original_scales = prev_results.original_scales;

        for i = 1:length(meshes)
            % Compute current scale
            centroid = mean(meshes{i}.vertices, 1);
            distances = sqrt(sum((meshes{i}.vertices - centroid).^2, 2));
            current_scale = sqrt(mean(distances.^2));

            % Rescale to original
            if current_scale > 0
                scale_factor = original_scales(i) / current_scale;
                meshes{i}.vertices = (meshes{i}.vertices - centroid) * scale_factor + centroid;
            end
        end

        logger(sprintf('Rescaled %d meshes to original anatomical size', length(meshes)), 'level', 'DEBUG');
    end

    % Step 3: Generalized Procrustes Analysis for final alignment
    logger('Phase 2d: Generalized Procrustes Analysis...');
    meshes = procrustes_align(meshes, config);

    results = prev_results;
    results.aligned_meshes = meshes;

end

function results = phase_ssm_building(config, prev_results)
    % Phase 3: Build SSM
    logger('Building Statistical Shape Model...', 'level', 'INFO');

    % Use complete SSM builder with shape normalization
    ssm_model = build_ssm_complete(prev_results.aligned_meshes, prev_results.metadata, config);

    % Save model
    save(config.paths.output.ssm_model, 'ssm_model', '-v7.3');
    logger(sprintf('SSM model saved: %s', config.paths.output.ssm_model));

    results = prev_results;
    results.ssm_model = ssm_model;

end

function results = phase_analysis(config, prev_results)
    % Phase 4: Statistical analysis
    if ~config.analysis.run_analysis
        logger('Statistical analysis disabled', 'level', 'INFO');
        results = prev_results;
        return;
    end

    logger('Performing statistical analysis...', 'level', 'INFO');

    analysis_results = sex_differences(prev_results.ssm_model, config);

    results = prev_results;
    results.analysis_results = analysis_results;

end

function results = phase_reconstruction(config, prev_results)
    % Phase 5: Clinical reconstruction
    if ~config.clinical.run_reconstruction
        logger('Clinical reconstruction disabled', 'level', 'INFO');
        results = prev_results;
        return;
    end

    % Find clinical cases
    clinical_files = dir(fullfile(config.paths.input.clinical, '*.stl'));

    if isempty(clinical_files)
        logger('No clinical cases found', 'level', 'WARNING');
        results = prev_results;
        return;
    end

    logger(sprintf('Found %d clinical cases to reconstruct', length(clinical_files)));

    reconstructions = cell(length(clinical_files), 1);

    for i = 1:length(clinical_files)
        case_file = fullfile(config.paths.input.clinical, clinical_files(i).name);
        reconstructions{i} = reconstruct_case(prev_results.ssm_model, case_file, config);
    end

    results = prev_results;
    results.reconstructions = reconstructions;

end

%% Helper Functions

function display_config(config)
    fprintf('--- Configuration ---\n');
    fprintf('Female STL: %s\n', config.paths.input.female);
    fprintf('Male STL: %s\n', config.paths.input.male);
    fprintf('Output: %s\n', config.paths.output.ssm_model);
    fprintf('Preprocessing: edge=%.1fmm, iters=%d\n', ...
        config.preprocessing.edge_length, config.preprocessing.remesh_iterations);
    fprintf('Registration: rigid=%d iters, nonrigid=%d iters\n', ...
        config.registration.rigid_icp.iterations, config.registration.nonrigid_icp.iterations);
    fprintf('SSM: max_components=%d\n', config.ssm.max_components);

    % Analysis status
    if isfield(config, 'analysis') && isfield(config.analysis, 'run_analysis') && config.analysis.run_analysis
        fprintf('Analysis: enabled\n');
    else
        fprintf('Analysis: disabled\n');
    end

    % Reconstruction status
    if isfield(config, 'clinical') && isfield(config.clinical, 'run_reconstruction') && config.clinical.run_reconstruction
        fprintf('Reconstruction: enabled\n');
    else
        fprintf('Reconstruction: disabled\n');
    end

    fprintf('-------------------\n\n');
end

function filename = get_checkpoint_file(config, phase_idx)
    phase_names = config.checkpoint.phases;
    if phase_idx <= length(phase_names)
        phase_name = phase_names{phase_idx};
    else
        phase_name = sprintf('phase_%d', phase_idx);
    end
    filename = fullfile(config.checkpoint.dir, sprintf('checkpoint_%s.mat', phase_name));
end

function merged = merge_structs(s1, s2)
    merged = s1;
    fields = fieldnames(s2);
    for i = 1:length(fields)
        merged.(fields{i}) = s2.(fields{i});
    end
end
