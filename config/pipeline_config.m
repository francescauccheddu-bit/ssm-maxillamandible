function config = pipeline_config()
% PIPELINE_CONFIG Configuration for SSM pipeline
%
% Returns configuration struct with all pipeline parameters

    %% Paths
    config.paths.training_female = 'data/training/female';
    config.paths.training_male = '';  % No male data

    % Input paths (for compatibility)
    config.paths.input.female = 'data/training/female';
    config.paths.input.male = '';
    config.paths.input.clinical = '';  % No clinical cases

    % Output paths
    config.paths.output.base = 'output';
    config.paths.output.ssm_model = 'output/ssm_model.mat';
    config.paths.cache = 'cache';

    %% Execution control
    config.execution.force_recompute = false;
    config.execution.start_from_phase = 1;
    config.execution.run_only_phase = [];

    %% Logging
    config.logging.enabled = true;
    config.logging.log_dir = 'output/logs';
    config.logging.level = 'INFO';

    %% Checkpointing (ENABLED to avoid recomputation)
    config.checkpoint.enabled = true;  % Save results after each phase
    config.checkpoint.dir = 'cache/checkpoints';
    config.checkpoint.phases = {'preprocessing', 'registration', 'ssm_building', 'analysis', 'reconstruction'};

    %% Preprocessing
    config.preprocessing.enable_remeshing = true;   % ENABLED per paper methodology
    config.preprocessing.remesh_enabled = true;     % Required to have same vertex count across all meshes
    config.preprocessing.target_edge_length = 1.5;  % 1.5mm per paper (originally used 1.5mm for 200 samples)
    config.preprocessing.edge_length = 1.5;         % Paper uses 1.5mm for uniform distribution
    config.preprocessing.remesh_iterations = 3;     % Paper uses iterative remeshing
    config.preprocessing.clean_mesh = true;         % Keep cleaning enabled

    %% Registration
    config.registration.reference_index = 1;
    config.registration.template_index = [];  % Auto-select (set to number to use specific template)
    config.registration.use_nonrigid = true;  % Enabled per paper
    config.registration.num_iterations = 3;  % 3 iterations per paper

    % Rigid ICP (affine registration)
    config.registration.rigid_icp.max_iterations = 100;
    config.registration.rigid_icp.iterations = 100;
    config.registration.rigid_icp.tolerance = 1e-6;

    % Non-rigid ICP
    config.registration.nonrigid_icp.max_iterations = 50;
    config.registration.nonrigid_icp.iterations = 15;  % Reduced per paper
    config.registration.nonrigid_icp.tolerance = 1e-4;
    config.registration.nonrigid_icp.lambda = 0.001;  % Regularization

    %% SSM
    config.ssm.max_components = 19;  % Max for 20 samples = n-1
    config.ssm.compute_sex_specific_means = false;  % Only female data
    config.ssm.normalize_scale = true;

    %% Analysis
    config.analysis.run_analysis = false;  % Disabled (no sex differences)

    %% Clinical reconstruction
    config.clinical.run_reconstruction = false;  % Disabled

    %% Visualization
    config.viz.export_mean_shapes = true;
    config.viz.export_pca_modes = true;
    config.viz.num_modes_to_export = 3;
    config.viz.mode_std_range = [-3, -2, -1, 0, 1, 2, 3];

    % Create output directories if they don't exist
    if ~exist(config.paths.output.base, 'dir')
        mkdir(config.paths.output.base);
    end
    if config.logging.enabled && ~exist(config.logging.log_dir, 'dir')
        mkdir(config.logging.log_dir);
    end
    if config.checkpoint.enabled && ~exist(config.checkpoint.dir, 'dir')
        mkdir(config.checkpoint.dir);
    end

end
