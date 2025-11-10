function ssm_model = build_ssm(meshes, metadata, config)
% BUILD_SSM Build Statistical Shape Model from aligned meshes
%
% Usage:
%   ssm_model = build_ssm(meshes, metadata, config)
%
% Parameters:
%   meshes - Cell array of mesh structs with .vertices (Nx3) and .faces (Mx3)
%   metadata - Struct with .sex (cell array of 'F'/'M') and .ids
%   config - Configuration struct from pipeline_config()
%
% Returns:
%   ssm_model - Struct with fields:
%       .mean_shape - Nx3 mean vertex coordinates
%       .eigenvectors - (3N)xK matrix of principal components
%       .eigenvalues - Kx1 variance per PC
%       .shape_vectors - (3N)xK shape mode vectors
%       .pc_scores - MxK PC scores for each specimen
%       .cumulative_variance - Kx1 cumulative variance
%       .metadata - Sex labels, IDs
%       .mean_shape_female - Nx3 female-specific mean
%       .mean_shape_male - Nx3 male-specific mean
%       .num_vertices - Number of vertices per mesh
%       .num_specimens - Number of training specimens

    logger('=== Building Statistical Shape Model ===', 'level', 'INFO');

    num_meshes = length(meshes);
    num_vertices = size(meshes{1}.vertices, 1);

    % Validate all meshes have same number of vertices
    for i = 1:num_meshes
        if size(meshes{i}.vertices, 1) ~= num_vertices
            error('build_ssm:InconsistentTopology', ...
                'All meshes must have the same number of vertices (mesh %d has %d vs expected %d)', ...
                i, size(meshes{i}.vertices, 1), num_vertices);
        end
    end

    logger(sprintf('Building SSM from %d specimens with %d vertices each', ...
        num_meshes, num_vertices));

    %% Construct Data Matrix
    % Stack X, Y, Z coordinates: [X1 X2 ... XN; Y1 Y2 ... YN; Z1 Z2 ... ZN]
    % Resulting matrix is (3*num_vertices) x num_meshes
    data_matrix = zeros(3 * num_vertices, num_meshes);

    for i = 1:num_meshes
        V = meshes{i}.vertices;
        data_matrix(:, i) = V(:);  % Vectorize: [X; Y; Z]
    end

    %% Perform PCA
    pca_results = compute_pca(data_matrix, ...
        'max_components', config.ssm.max_components, ...
        'variance_threshold', config.ssm.variance_threshold);

    %% Reshape Mean Shape
    mean_shape_vec = pca_results.mean_shape;
    mean_shape = reshape(mean_shape_vec, num_vertices, 3);

    %% Compute Sex-Specific Means
    if config.ssm.compute_sex_specific_means
        logger('Computing sex-specific mean shapes...');

        % Find female and male indices
        is_female = strcmp(metadata.sex, 'F');
        is_male = strcmp(metadata.sex, 'M');

        % Female mean
        if any(is_female)
            female_data = data_matrix(:, is_female);
            mean_shape_female_vec = mean(female_data, 2);
            mean_shape_female = reshape(mean_shape_female_vec, num_vertices, 3);
            logger(sprintf('Female mean computed from %d specimens', sum(is_female)));
        else
            mean_shape_female = mean_shape;
            logger('No female specimens found, using global mean', 'level', 'WARNING');
        end

        % Male mean
        if any(is_male)
            male_data = data_matrix(:, is_male);
            mean_shape_male_vec = mean(male_data, 2);
            mean_shape_male = reshape(mean_shape_male_vec, num_vertices, 3);
            logger(sprintf('Male mean computed from %d specimens', sum(is_male)));
        else
            mean_shape_male = mean_shape;
            logger('No male specimens found, using global mean', 'level', 'WARNING');
        end
    else
        mean_shape_female = mean_shape;
        mean_shape_male = mean_shape;
    end

    %% Package SSM Model
    ssm_model.mean_shape = mean_shape;
    ssm_model.eigenvectors = pca_results.eigenvectors;
    ssm_model.eigenvalues = pca_results.eigenvalues;
    ssm_model.shape_vectors = pca_results.shape_vectors;
    ssm_model.pc_scores = pca_results.pc_scores;
    ssm_model.variance_explained = pca_results.variance_explained;
    ssm_model.cumulative_variance = pca_results.cumulative_variance;
    ssm_model.num_components = pca_results.num_components;
    ssm_model.metadata = metadata;
    ssm_model.mean_shape_female = mean_shape_female;
    ssm_model.mean_shape_male = mean_shape_male;
    ssm_model.num_vertices = num_vertices;
    ssm_model.num_specimens = num_meshes;
    ssm_model.faces = meshes{1}.faces;  % All meshes share same topology

    %% Summary
    logger('=== SSM Building Complete ===', 'level', 'INFO');
    logger(sprintf('Model specifications:'));
    logger(sprintf('  - Specimens: %d (%d F, %d M)', ...
        num_meshes, sum(is_female), sum(is_male)));
    logger(sprintf('  - Vertices: %d', num_vertices));
    logger(sprintf('  - Components: %d', pca_results.num_components));
    logger(sprintf('  - Variance explained (PC1): %.1f%%', ...
        pca_results.variance_explained(1)*100));
    logger(sprintf('  - Cumulative variance (all PCs): %.1f%%', ...
        pca_results.cumulative_variance(end)*100));

end
