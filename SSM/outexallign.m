function [aligned_shape] = outexallign(template, target, use_scaling)
    % OUTEXALLIGN - Allineamento Procrustes con esclusione outlier
    %
    % INPUT:
    %   template - Shape di riferimento (M x 3 matrix)
    %   target - Shape da allineare (M x 3 matrix)
    %   use_scaling - Boolean per includere/escludere scaling
    %
    % OUTPUT:
    %   aligned_shape - Shape allineato (M x 3 matrix)
    %
    % La funzione esegue allineamento Procrustes ed esclude
    % outlier al livello di significatività 0.05

    % Numero di punti
    n_points = size(template, 1);

    % Esegui Procrustes alignment iniziale
    [~, aligned_shape, transform] = procrustes(template, target, ...
        'Scaling', use_scaling, 'Reflection', false);

    % Calcola distanze punto-per-punto dopo l'allineamento
    distances = sqrt(sum((template - aligned_shape).^2, 2));

    % Identifica outlier usando la regola dei 3-sigma (approssimazione per p=0.05)
    % Per distribuzione normale, ~95% dei dati è entro 2*sigma
    mean_dist = mean(distances);
    std_dist = std(distances);
    threshold = mean_dist + 2 * std_dist;  % Soglia per outlier (≈ p=0.05)

    % Trova gli inliers (punti non-outlier)
    inliers = distances <= threshold;

    % Se ci sono troppi outlier (>50%), usa tutti i punti
    if sum(inliers) < n_points * 0.5
        % warning('Troppi outlier rilevati (>50%%). Uso tutti i punti.');
        return;
    end

    % Se ci sono outlier, riallinea usando solo gli inliers
    if sum(~inliers) > 0
        % Riallinea usando solo i punti inlier
        [~, ~, transform_refined] = procrustes(template(inliers, :), ...
            target(inliers, :), 'Scaling', use_scaling, 'Reflection', false);

        % Applica la trasformazione raffinata a tutti i punti
        % Z = b * Y * T + c
        aligned_shape = transform_refined.b * target * transform_refined.T + ...
            repmat(transform_refined.c(1,:), n_points, 1);
    end
end
