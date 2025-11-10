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

    %% Add Paths
    [pipeline_dir, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(pipeline_dir, 'src')));
    addpath(fullfile(pipeline_dir, 'config'));

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
            tic;
            phase_results = phase_func(config, results);
            elapsed = toc;

            logger(sprintf('Phase %d completed in %.1f seconds (%.1f min)', ...
                i, elapsed, elapsed/60), 'level', 'INFO');

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

    fprintf('\nFinished: %s\n', datestr(now));
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

    % Normalize meshes
    logger('Normalizing meshes...');
    for i = 1:length(meshes)
        meshes{i} = normalize_mesh(meshes{i}, config);
    end

    % Remesh (optional, simplified version)
    if config.preprocessing.remesh_enabled
        logger('Remeshing meshes (simplified)...');
        % Note: Full remeshing requires external libraries
        % This is a placeholder for the remeshing step
        for i = 1:length(meshes)
            % In production, call: meshes{i} = remesh_isotropic(meshes{i}, config);
            % For now, skip remeshing
        end
    end

    results.meshes = meshes;
    results.metadata = metadata;

end

function results = phase_registration(config, prev_results)
    % Phase 2: Register all meshes
    logger('Registering meshes...', 'level', 'INFO');

    meshes = prev_results.meshes;

    % Step 1: Rigid ICP alignment to first mesh (template)
    logger('Rigid ICP alignment...');
    template = meshes{1}.vertices;

    for i = 2:length(meshes)
        [meshes{i}.vertices, ~] = rigid_icp(meshes{i}.vertices, template, config);
    end

    % Step 2: Generalized Procrustes Analysis
    logger('Generalized Procrustes Analysis...');
    meshes = procrustes_align(meshes, config);

    results = prev_results;
    results.aligned_meshes = meshes;

end

function results = phase_ssm_building(config, prev_results)
    % Phase 3: Build SSM
    logger('Building Statistical Shape Model...', 'level', 'INFO');

    ssm_model = build_ssm(prev_results.aligned_meshes, prev_results.metadata, config);

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
    fprintf('Analysis: %s\n', config.analysis.run_analysis ? 'enabled' : 'disabled');
    fprintf('Reconstruction: %s\n', config.clinical.run_reconstruction ? 'enabled' : 'disabled');
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
