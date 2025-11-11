function mesh = normalize_mesh(mesh, config)
% NORMALIZE_MESH Center and scale mesh to unit sphere
%
% Syntax:
%   mesh = normalize_mesh(mesh, config)
%
% Inputs:
%   mesh - Struct with .vertices and .faces
%   config - Configuration struct (optional)
%
% Outputs:
%   mesh - Normalized mesh struct
%
% Example:
%   mesh = normalize_mesh(mesh, config);

    % Center mesh at origin
    centroid = mean(mesh.vertices, 1);
    mesh.vertices = mesh.vertices - centroid;

    % Scale to unit sphere (DISABLED by default to preserve mm units for remeshing)
    % Scaling happens later in SSM building if needed
    if nargin >= 2 && isfield(config, 'preprocessing') && ...
       isfield(config.preprocessing, 'normalize_scale') && ...
       config.preprocessing.normalize_scale
        max_dist = max(sqrt(sum(mesh.vertices.^2, 2)));
        if max_dist > 0
            mesh.vertices = mesh.vertices / max_dist;
        end
    end

end
