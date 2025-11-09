function [RMSE_vector, ReallignedV, SSMfit_cell, EstimatedModes_cell] = SSMfitter_batch(MEAN, Fmodel, ssmV, V, F, modes_to_test)
% SSMfitter_batch - Optimized batch version of SSMfitter for testing multiple numbers of modes
%
% This function fits an SSM to a given shape and tests multiple numbers of shape modes
% efficiently by performing the iterative ICP convergence ONCE (with max modes) and then
% re-estimating coefficients for each mode count using the same alignment.
% This is 5-10x faster than calling SSMfitter repeatedly.
%
% OPTIMIZATION STRATEGY:
%   Original SSMfitter: For each mode count (1 to 30):
%     - Rigid ICP alignment
%     - Iterative ICP loop until convergence (5-10 iterations)
%     - Compute RMSE
%   Total: 30 × (1 rigid ICP + 5-10 iterative ICP) = 150-300 ICP operations
%
%   SSMfitter_batch:
%     - Rigid ICP alignment (once)
%     - Iterative ICP loop with max modes until convergence (once, 5-10 iterations)
%     - For each mode count: single coefficient estimation (no iterations)
%   Total: 1 rigid ICP + 5-10 iterative ICP + 30 single estimations
%   Speedup: ~5-10x
%
% INPUT:
%   MEAN            : Mean shape vector (M×1 vector)
%   Fmodel          : Triangulation matrix of the model (P×3 matrix)
%   ssmV            : Shape vectors (M×N matrix)
%   V               : Vertices of the given shape
%   F               : Triangulation matrix of the given shape
%   modes_to_test   : Vector of mode counts to test (e.g., 1:30)
%
% OUTPUT:
%   RMSE_vector     : Vector of RMSE values for each number of modes tested
%   ReallignedV     : Realigned shape after fitting
%   SSMfit_cell     : Cell array of fitted SSM shapes for each mode count
%   EstimatedModes_cell : Cell array of estimated mode coefficients for each mode count
%
% EXAMPLE:
%   [RMSE_vector, ~, ~, ~] = SSMfitter_batch(MEAN, Fmodel, ssmV, V, F, 1:30);
%
% Author: Optimized version for LOO validation speed
% Date: 2025-11-04

[p, q] = size(ssmV);
s = p / 3;
MEANX = MEAN(1:s);
MEANY = MEAN(s+1:2*s);
MEANZ = MEAN(2*s+1:3*s);
MeanParentbone = [MEANX, MEANY, MEANZ];

% Step 1: Initial rigid ICP alignment (do this ONCE)
[~, ReallignedVtarget, ~] = rigidICP_SSM(MeanParentbone, V);

% Prepare shape mode matrices
BTXX = ssmV(1:p/3, :);
BTXY = ssmV(p/3+1:2*(p/3), :);
BTXZ = ssmV(2*(p/3)+1:end, :);

% Determine maximum number of modes to use
max_modes = max(modes_to_test);
if max_modes > q
    max_modes = q;
    warning('Requested modes exceed available modes. Using max available: %d', q);
end

% Step 2: Iterative ICP alignment with max modes to get stable alignment
errortemp = zeros(1, 100);
errortemp(1) = 0;
index = 2;
estimate = MeanParentbone;
Reallignedtargettemp_aligned = ReallignedVtarget;

% Converge with maximum modes for best alignment
[errortemp(index), Reallignedtargettemp_aligned, estimate, ~] = ...
    ICPmanu_allignSSM(Reallignedtargettemp_aligned, MeanParentbone, estimate, BTXX, BTXY, BTXZ, max_modes);

while (abs(errortemp(index-1) - errortemp(index))) > 0.000001 && index < 100
    [errortemp(index+1), Reallignedtargettemp_aligned, estimate, ~] = ...
        ICPmanu_allignSSM(Reallignedtargettemp_aligned, MeanParentbone, estimate, BTXX, BTXY, BTXZ, max_modes);
    index = index + 1;
end

% Get final realigned V for RMSE computation
[~, ReallignedV, ~] = procrustes(Reallignedtargettemp_aligned, V, 'scaling', 0);

% Step 3: For each number of modes, compute optimal coefficients and RMSE
% We re-estimate coefficients for each mode count, but use the SAME alignment
% This is more accurate than using a subset of max-mode coefficients
num_tests = length(modes_to_test);
RMSE_vector = zeros(1, num_tests);
SSMfit_cell = cell(1, num_tests);
EstimatedModes_cell = cell(1, num_tests);

for i = 1:num_tests
    n_modes = modes_to_test(i);

    % Re-estimate coefficients for THIS specific number of modes
    % using the already-aligned shape (this is fast, no ICP iterations)
    % This matches the original SSMfitter behavior more closely
    [~, ~, estimate_n, EstimatedModes_n] = ...
        ICPmanu_allignSSM(Reallignedtargettemp_aligned, MeanParentbone, MeanParentbone, BTXX, BTXY, BTXZ, n_modes);

    SSMfit = estimate_n;

    % Project and compute RMSE
    [projections] = project(SSMfit, Fmodel, ReallignedV, F);
    RMSE_vector(i) = sqrt(mean((sqrt(sum((projections - SSMfit).^2, 2)).^2)));

    % Store results if needed
    SSMfit_cell{i} = SSMfit;
    EstimatedModes_cell{i} = EstimatedModes_n;
end

end
