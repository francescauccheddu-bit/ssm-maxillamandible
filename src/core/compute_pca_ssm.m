function pca_results = compute_pca_ssm(data_matrix, max_components)
% COMPUTE_PCA_SSM PCA computation optimized for SSM
%
% Performs PCA using SVD with proper normalization for statistical
% shape modeling.
%
% Syntax:
%   pca_results = compute_pca_ssm(data_matrix, max_components)
%
% Inputs:
%   data_matrix - (3N)xM matrix where N=vertices, M=specimens
%   max_components - Maximum PCs to compute
%
% Outputs:
%   pca_results - Struct with PCA results
%
% See also: build_ssm_complete

    [num_features, num_samples] = size(data_matrix);

    % Compute mean
    mean_shape = mean(data_matrix, 2);

    % Center data
    data_centered = data_matrix - mean_shape;

    % Normalize by sqrt(n-1) for unbiased covariance
    data_normalized = data_centered / sqrt(num_samples - 1);

    % SVD
    if num_features > num_samples
        % Use economy SVD
        [U, S, ~] = svd(data_normalized', 'econ');
        eigenvectors = data_normalized * U / S;
        eigenvalues = diag(S).^2;
    else
        [U, S, ~] = svd(data_normalized, 'econ');
        eigenvectors = U;
        eigenvalues = diag(S).^2;
    end

    % Limit components
    num_components = min(max_components, length(eigenvalues));
    eigenvectors = eigenvectors(:, 1:num_components);
    eigenvalues = eigenvalues(1:num_components);

    % Shape vectors (scaled eigenvectors)
    shape_vectors = eigenvectors * diag(sqrt(eigenvalues));

    % PC scores
    pc_scores = (data_matrix - mean_shape)' * eigenvectors;

    % Variance explained
    total_variance = sum(eigenvalues);
    variance_explained = eigenvalues / total_variance;
    cumulative_variance = cumsum(variance_explained);

    % Package results
    pca_results.mean_shape = mean_shape;
    pca_results.eigenvectors = eigenvectors;
    pca_results.eigenvalues = eigenvalues;
    pca_results.shape_vectors = shape_vectors;
    pca_results.pc_scores = pc_scores;
    pca_results.variance_explained = variance_explained;
    pca_results.cumulative_variance = cumulative_variance;
    pca_results.num_components = num_components;

end
