function reconstructed_mesh = reconstruct_from_ssm(ssm_model, pc_scores, varargin)
% RECONSTRUCT_FROM_SSM Reconstruct shape from PC scores
%
% Usage:
%   mesh = reconstruct_from_ssm(ssm_model, pc_scores)
%   mesh = reconstruct_from_ssm(ssm_model, pc_scores, 'num_pcs', 5)
%
% Parameters:
%   ssm_model - SSM model struct from build_ssm()
%   pc_scores - 1xK or Kx1 vector of PC scores
%   'num_pcs' - Number of PCs to use (default: length(pc_scores))
%
% Returns:
%   reconstructed_mesh - Struct with .vertices (Nx3) and .faces (Mx3)
%
% Reconstruction formula:
%   shape = mean_shape + sum(pc_scores(i) * eigenvectors(:,i))

    p = inputParser;
    addRequired(p, 'ssm_model', @isstruct);
    addRequired(p, 'pc_scores', @isnumeric);
    addParameter(p, 'num_pcs', [], @isnumeric);
    parse(p, ssm_model, pc_scores, varargin{:});

    % Convert pc_scores to column vector
    pc_scores = pc_scores(:);

    % Determine number of PCs to use
    num_pcs = p.Results.num_pcs;
    if isempty(num_pcs)
        num_pcs = length(pc_scores);
    end
    num_pcs = min(num_pcs, length(pc_scores));
    num_pcs = min(num_pcs, size(ssm_model.eigenvectors, 2));

    % Extract components
    mean_shape_vec = ssm_model.mean_shape(:);  % Vectorize
    eigenvectors = ssm_model.eigenvectors(:, 1:num_pcs);
    pc_scores = pc_scores(1:num_pcs);

    % Reconstruct shape
    reconstructed_vec = mean_shape_vec + eigenvectors * pc_scores;

    % Reshape to Nx3
    num_vertices = ssm_model.num_vertices;
    reconstructed_vertices = reshape(reconstructed_vec, num_vertices, 3);

    % Package mesh
    reconstructed_mesh.vertices = reconstructed_vertices;
    reconstructed_mesh.faces = ssm_model.faces;

end
