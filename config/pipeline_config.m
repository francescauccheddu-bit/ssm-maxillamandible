function config = pipeline_config()
% PIPELINE_CONFIG Configuration for SSM pipeline
%
% Returns configuration struct with all pipeline parameters

    %% Paths
    config.paths.training_female = 'data/training/female';
    config.paths.training_male = '';  % No male data
    config.paths.output = 'output';
    config.paths.cache = 'cache';
    
    %% Preprocessing
    config.preprocess.enable_remeshing = true;
    config.preprocess.target_edge_length = [];  % Auto-calculate from data
    config.preprocess.remesh_iterations = 3;
    config.preprocess.clean_mesh = true;
    
    %% Registration
    config.registration.reference_index = 1;  % Use first specimen as reference
    config.registration.rigid_icp_max_iterations = 100;
    config.registration.rigid_icp_tolerance = 1e-6;
    config.registration.nonrigid_enable = true;
    config.registration.nonrigid_max_iterations = 50;
    config.registration.nonrigid_tolerance = 1e-4;
    
    %% SSM
    config.ssm.max_components = 19;  % Max for 20 samples = n-1
    config.ssm.compute_sex_specific_means = false;  % Only female data
    config.ssm.normalize_scale = true;  % Remove size effects
    
    %% Visualization
    config.viz.export_mean_shapes = true;
    config.viz.export_pca_modes = true;
    config.viz.num_modes_to_export = 3;
    config.viz.mode_std_range = [-3, -2, -1, 0, 1, 2, 3];
    
    %% Logging
    config.log.level = 'INFO';  % DEBUG, INFO, WARNING, ERROR
    config.log.save_to_file = true;
    
end