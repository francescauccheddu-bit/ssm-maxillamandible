function ssm_model = build_ssm_complete(meshes_aligned, metadata, config)
% BUILD_SSM_COMPLETE Complete SSM building with shape alignment and PCA
%
% Builds Statistical Shape Model with proper shape normalization including
% scaling to capture only shape variation (not size differences).
%
% This is the complete production version that:
%   1. Re-aligns shapes with scaling enabled
%   2. Computes PCA on normalized shapes
%   3. Computes shape modes and projections
%   4. Generates sex-specific mean shapes
%
% Syntax:
%   ssm_model = build_ssm_complete(meshes, metadata, config)
%
% Inputs:
%   meshes_aligned - Cell array of aligned mesh structs
%   metadata - Struct with .sex labels
%   config - Configuration struct
%
% Outputs:
%   ssm_model - Complete SSM model struct
%
% See also: compute_pca_ssm, realign_shapes_with_scaling

    logger('Building complete SSM with shape normalization...', 'level', 'INFO');

    num_meshes = length(meshes_aligned);
    num_vertices = size(meshes_aligned{1}.vertices, 1);

    % Stack coordinates into matrices
    X_data = zeros(num_vertices, num_meshes);
    Y_data = zeros(num_vertices, num_meshes);
    Z_data = zeros(num_vertices, num_meshes);

    for i = 1:num_meshes
        V = meshes_aligned{i}.vertices;
        X_data(:, i) = V(:, 1);
        Y_data(:, i) = V(:, 2);
        Z_data(:, i) = V(:, 3);
    end

    %% Re-alignment with scaling (critical step!)
    % This removes scale differences and focuses on shape variation only
    logger('Re-aligning shapes with scaling normalization...', 'level', 'DEBUG');

    [X_norm, Y_norm, Z_norm, alignment_info] = realign_shapes_with_scaling(X_data, Y_data, Z_data);

    %% Build training matrix
    training_matrix = [X_norm; Y_norm; Z_norm];  % (3N) x M

    %% Perform PCA
    logger('Computing PCA...', 'level', 'DEBUG');

    pca_results = compute_pca_ssm(training_matrix, config.ssm.max_components);

    %% Compute shape modes
    % Remove last singular vector (rank deficient by 1)
    shape_vectors = pca_results.shape_vectors(:, 1:end-1);

    % Project training data onto shape space
    num_components = size(shape_vectors, 2);
    shape_modes = zeros(num_meshes, num_components);

    for i = 1:num_meshes
        shape_vec = training_matrix(:, i) - pca_results.mean_shape;
        shape_modes(i, :) = (pinv(shape_vectors) * shape_vec)';
    end

    %% Compute sex-specific means
    if config.ssm.compute_sex_specific_means
        is_female = strcmp(metadata.sex, 'F');
        is_male = strcmp(metadata.sex, 'M');

        % Female mean
        if any(is_female)
            female_data = training_matrix(:, is_female);
            mean_female_vec = mean(female_data, 2);
            mean_female = reshape(mean_female_vec, num_vertices, 3);
        else
            mean_female = [];
        end

        % Male mean
        if any(is_male)
            male_data = training_matrix(:, is_male);
            mean_male_vec = mean(male_data, 2);
            mean_male = reshape(mean_male_vec, num_vertices, 3);
        else
            mean_male = [];
        end
    else
        mean_female = [];
        mean_male = [];
    end

    %% Package SSM model
    mean_shape = reshape(pca_results.mean_shape, num_vertices, 3);

    ssm_model.mean_shape = mean_shape;
    ssm_model.mean_shape_female = mean_female;
    ssm_model.mean_shape_male = mean_male;
    ssm_model.shape_vectors = shape_vectors;
    ssm_model.eigenvalues = pca_results.eigenvalues(1:num_components);
    ssm_model.eigenvectors = pca_results.eigenvectors(:, 1:num_components);
    ssm_model.variance_explained = pca_results.variance_explained(1:num_components);
    ssm_model.cumulative_variance = pca_results.cumulative_variance(1:num_components);
    ssm_model.shape_modes = shape_modes;
    ssm_model.pc_scores = pca_results.pc_scores(:, 1:num_components);
    ssm_model.num_components = num_components;
    ssm_model.num_vertices = num_vertices;
    ssm_model.num_specimens = num_meshes;
    ssm_model.faces = meshes_aligned{1}.faces;
    ssm_model.metadata = metadata;
    ssm_model.alignment_info = alignment_info;

    logger(sprintf('SSM complete: %d components, %.1f%% variance explained', ...
        num_components, pca_results.cumulative_variance(num_components)*100), ...
        'level', 'INFO');

end
