function mesh = normalize_mesh(mesh, config)
% NORMALIZE_MESH Center mesh at origin and optionally scale
%
% Usage:
%   mesh_normalized = normalize_mesh(mesh, config)
%
% Parameters:
%   mesh - Struct with .vertices (Nx3) and .faces (Mx3)
%   config - Configuration struct with .preprocessing settings
%
% Returns:
%   mesh - Normalized mesh (struct with .vertices and .faces)
%
% Operations:
%   1. Center mesh at origin (centroid = [0,0,0])
%   2. Optionally normalize scale (unit bounding box)

    vertices = mesh.vertices;

    % Center mesh
    if config.preprocessing.center_meshes
        centroid = mean(vertices, 1);
        vertices = vertices - centroid;
    end

    % Normalize scale
    if config.preprocessing.normalize_scale
        % Compute bounding box diagonal
        bbox_min = min(vertices, [], 1);
        bbox_max = max(vertices, [], 1);
        bbox_diag = norm(bbox_max - bbox_min);

        % Scale to unit bounding box
        if bbox_diag > eps
            vertices = vertices / bbox_diag;
        end
    end

    % Return normalized mesh
    mesh.vertices = vertices;

end
