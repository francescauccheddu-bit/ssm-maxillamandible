function pca_results = compute_pca(data_matrix, varargin)
% COMPUTE_PCA Perform Principal Component Analysis on shape data
%
% Usage:
%   pca_results = compute_pca(data_matrix)
%   pca_results = compute_pca(data_matrix, 'max_components', 15)
%
% Parameters:
%   data_matrix - MxN matrix where M is number of features (3*num_vertices)
%                 and N is number of samples
%   'max_components' - Maximum number of PCs to compute (default: min(M,N))
%   'variance_threshold' - Cumulative variance threshold (default: 0.95)
%
% Returns:
%   pca_results - Struct with fields:
%       .mean_shape - Mx1 mean shape vector
%       .eigenvectors - MxK matrix of eigenvectors (PCs)
%       .eigenvalues - Kx1 vector of eigenvalues
%       .shape_vectors - MxK matrix (sqrt(eigenvalues) * eigenvectors)
%       .pc_scores - NxK matrix of PC scores for each sample
%       .cumulative_variance - Kx1 cumulative variance explained
%       .num_components - Number of components computed

    p = inputParser;
    addRequired(p, 'data_matrix', @isnumeric);
    addParameter(p, 'max_components', [], @isnumeric);
    addParameter(p, 'variance_threshold', 0.95, @isnumeric);
    parse(p, data_matrix, varargin{:});

    max_comps = p.Results.max_components;
    var_thresh = p.Results.variance_threshold;

    [M, N] = size(data_matrix);

    logger(sprintf('Computing PCA on %dx%d data matrix...', M, N), 'level', 'INFO');

    % Compute mean shape
    mean_shape = mean(data_matrix, 2);

    % Center data
    centered_data = data_matrix - mean_shape;

    % Normalize by sqrt(N-1) for unbiased covariance
    centered_data = centered_data / sqrt(N - 1);

    % Determine number of components to compute
    if isempty(max_comps)
        max_comps = min(M, N) - 1;
    else
        max_comps = min(max_comps, min(M, N) - 1);
    end

    logger(sprintf('Computing %d principal components...', max_comps));

    % Perform SVD
    % For large matrices, use economy-size decomposition
    if M > N
        [U, S, ~] = svd(centered_data', 'econ');
        eigenvectors = centered_data * U * inv(S);
        eigenvalues = diag(S).^2;
    else
        [U, S, ~] = svd(centered_data, 'econ');
        eigenvectors = U;
        eigenvalues = diag(S).^2;
    end

    % Keep only requested number of components
    eigenvectors = eigenvectors(:, 1:max_comps);
    eigenvalues = eigenvalues(1:max_comps);

    % Compute shape vectors
    shape_vectors = eigenvectors * diag(sqrt(eigenvalues));

    % Compute PC scores for each sample
    pc_scores = eigenvectors' * (data_matrix - mean_shape);
    pc_scores = pc_scores';  % Transpose to NxK

    % Compute cumulative variance explained
    total_variance = sum(eigenvalues);
    variance_explained = eigenvalues / total_variance;
    cumulative_variance = cumsum(variance_explained);

    % Find number of components explaining variance_threshold
    num_comps_threshold = find(cumulative_variance >= var_thresh, 1, 'first');
    if isempty(num_comps_threshold)
        num_comps_threshold = max_comps;
    end

    % Package results
    pca_results.mean_shape = mean_shape;
    pca_results.eigenvectors = eigenvectors;
    pca_results.eigenvalues = eigenvalues;
    pca_results.shape_vectors = shape_vectors;
    pca_results.pc_scores = pc_scores;
    pca_results.variance_explained = variance_explained;
    pca_results.cumulative_variance = cumulative_variance;
    pca_results.num_components = max_comps;
    pca_results.num_components_threshold = num_comps_threshold;

    % Log results
    logger(sprintf('PCA complete: %d components computed', max_comps));
    logger(sprintf('First PC explains %.1f%% variance', variance_explained(1)*100));
    logger(sprintf('%d PCs explain %.1f%% cumulative variance', ...
        num_comps_threshold, var_thresh*100));

end
