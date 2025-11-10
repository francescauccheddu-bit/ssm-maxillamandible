function config = pipeline_config()
% PIPELINE_CONFIG Configuration settings for SSM pipeline
%
% Returns a struct with all pipeline parameters and paths.
%
% Usage:
%   config = pipeline_config();
%
% Sections:
%   - paths: Input/output paths
%   - preprocessing: Remeshing parameters
%   - registration: ICP and Procrustes settings
%   - ssm: PCA and model building
%   - analysis: Statistical testing
%   - clinical: Reconstruction parameters
%   - logging: Logging and checkpoints

    % Base directory (parent of config/)
    [config_dir, ~, ~] = fileparts(mfilename('fullpath'));
    base_dir = fileparts(config_dir);

    %% Paths
    config.paths.base = base_dir;
    config.paths.data = fullfile(base_dir, 'data');

    % Input
    config.paths.input.female = fullfile(config.paths.data, 'input', 'female');
    config.paths.input.male = fullfile(config.paths.data, 'input', 'male');
    config.paths.input.clinical = fullfile(config.paths.data, 'input', 'clinical_cases');

    % Output
    config.paths.output.base = fullfile(config.paths.data, 'output');
    config.paths.output.models = fullfile(config.paths.output.base, 'models');
    config.paths.output.results = fullfile(config.paths.output.base, 'results');
    config.paths.output.reconstructions = fullfile(config.paths.output.base, 'reconstructions');
    config.paths.output.checkpoints = fullfile(config.paths.output.base, 'checkpoints');

    % Model file
    config.paths.output.ssm_model = fullfile(config.paths.output.models, 'ssm_model.mat');

    %% Preprocessing
    config.preprocessing.remesh_enabled = true;
    config.preprocessing.edge_length = 1.0;  % mm
    config.preprocessing.remesh_iterations = 3;
    config.preprocessing.center_meshes = true;
    config.preprocessing.normalize_scale = true;

    %% Registration
    % Rigid ICP
    config.registration.rigid_icp.iterations = 50;
    config.registration.rigid_icp.tolerance = 1e-6;

    % Non-rigid ICP
    config.registration.nonrigid_icp.iterations = 15;
    config.registration.nonrigid_icp.lambda = 0.001;
    config.registration.nonrigid_icp.k_neighbors = 12;

    % Procrustes
    config.registration.procrustes.max_iterations = 5;
    config.registration.procrustes.tolerance = 1e-4;
    config.registration.procrustes.allow_scaling = true;

    % Strategy
    config.registration.num_registration_iterations = 3;
    config.registration.remesh_between_iterations = true;
    config.registration.remesh_frequency = 2;

    %% SSM Building
    config.ssm.compute_sex_specific_means = true;
    config.ssm.variance_threshold = 0.95;
    config.ssm.max_components = 15;

    %% Analysis
    config.analysis.run_analysis = true;
    config.analysis.significance_level = 0.05;
    config.analysis.correction_method = 'bonferroni';
    config.analysis.effect_size_metric = 'cohen_d';
    config.analysis.num_pcs_to_test = 15;

    % Effect size thresholds
    config.analysis.effect_size.small = 0.2;
    config.analysis.effect_size.medium = 0.5;
    config.analysis.effect_size.large = 0.8;

    %% Clinical Reconstruction
    config.clinical.run_reconstruction = true;
    config.clinical.auto_detect_cases = true;
    config.clinical.num_pcs = 5;
    config.clinical.registration_iterations = 50;
    config.clinical.export_visualizations = true;

    %% Logging and Checkpoints
    config.logging.enabled = true;
    config.logging.verbose = true;
    config.logging.save_logs = true;
    config.logging.log_dir = fullfile(config.paths.output.base, 'logs');

    config.checkpoint.enabled = true;
    config.checkpoint.dir = config.paths.output.checkpoints;
    config.checkpoint.phases = {'preprocessing', 'registration', 'ssm_building', 'analysis', 'reconstruction'};

    %% Execution
    config.execution.start_from_phase = 1;
    config.execution.run_only_phase = [];
    config.execution.force_recompute = false;

    %% Visualization
    config.visualization.generate_figures = true;
    config.visualization.save_figures = true;
    config.visualization.figure_format = 'png';
    config.visualization.figure_dpi = 300;

    %% Create Output Directories
    dirs_to_create = {
        config.paths.output.base,
        config.paths.output.models,
        config.paths.output.results,
        config.paths.output.reconstructions,
        config.paths.output.checkpoints,
        config.logging.log_dir
    };

    for i = 1:length(dirs_to_create)
        if ~exist(dirs_to_create{i}, 'dir')
            mkdir(dirs_to_create{i});
        end
    end

end
