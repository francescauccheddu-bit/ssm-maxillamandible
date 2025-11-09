%% Reconstruct Real Clinical Case (No Ground Truth Available)
% =========================================================================
% This script reconstructs a REAL damaged mandible using the SSM.
%
% DESIGNED FOR: True clinical cases where we only have the damaged/defective
%               mandible and NO complete reference for comparison.
%
% USE CASES:
%   - Real patient data with congenital defects
%   - Traumatic injuries where original anatomy is unknown
%   - Tumor resections requiring reconstruction planning
%   - Asymmetry correction where contralateral side is affected
%
% INPUT:
%   Place the damaged mandible STL file in: input_cases/
%   Filename: real_clinical_case.stl
%
% OUTPUT:
%   - Reconstructed mandible STL
%   - Visual comparison (damaged vs reconstructed vs mean shape)
%   - Qualitative analysis report
%   - No RMSE metrics (no ground truth available)
%
% Author: Francesca Uccheddu
% Date: November 2025
% =========================================================================

% NOTE: When called from RUN_FULL_ANALYSIS, do NOT clear workspace!
% This preserves variables like pipeline_success
if ~exist('pipeline_success', 'var')
    % Running standalone - safe to clear
    clear;
end
clc; close all;

fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════╗\n');
fprintf('║  REAL CLINICAL CASE RECONSTRUCTION                         ║\n');
fprintf('║  (No Ground Truth Available)                               ║\n');
fprintf('╚════════════════════════════════════════════════════════════╝\n');
fprintf('\n');

%% Configuration
CONFIG = struct();
CONFIG.base_dir = pwd;
CONFIG.checkpoint_file = fullfile(CONFIG.base_dir, 'output', 'checkpoints', 'phase3_ssm_v2.mat');
CONFIG.input_file = fullfile(CONFIG.base_dir, 'input_cases', 'real_clinical_case.stl');
CONFIG.output_dir = fullfile(CONFIG.base_dir, 'output', 'results', 'clinical_reconstruction');
CONFIG.num_pcs = 5;  % was 15 Number of PCs for reconstruction

% Create output directory
if ~exist(CONFIG.output_dir, 'dir')
    mkdir(CONFIG.output_dir);
end

%% Check Input File
if ~exist(CONFIG.input_file, 'file')
    fprintf('❌ ERROR: Clinical case file not found!\n\n');
    fprintf('Expected file: %s\n\n', CONFIG.input_file);
    fprintf('Please:\n');
    fprintf('  1. Place your damaged mandible STL in: input_cases/\n');
    fprintf('  2. Name it: real_clinical_case.stl\n');
    fprintf('  3. Run this script again\n\n');
    return;
end

%% Load SSM
fprintf('Loading Statistical Shape Model...\n');
if ~exist(CONFIG.checkpoint_file, 'file')
    fprintf('❌ ERROR: SSM checkpoint not found!\n');
    fprintf('   Please run PIPELINE_SSM_MODULAR_V2.m first.\n\n');
    return;
end

data = load(CONFIG.checkpoint_file);
ssm_data = data.ssm_data;

% Extract SSM components
mean_vec = ssm_data.MEAN;
num_vertices_template = size(ssm_data.Xdata, 1);
faces_template = ssm_data.Fdata;
eigenvectors = ssm_data.ssmV;
eigenvalues = ssm_data.eigenvalues;
explained_variance = ssm_data.explained;

% Reshape mean shape
x_mean = mean_vec(1:num_vertices_template);
y_mean = mean_vec(num_vertices_template+1:2*num_vertices_template);
z_mean = mean_vec(2*num_vertices_template+1:3*num_vertices_template);
mean_shape = [x_mean, y_mean, z_mean];

fprintf('✓ SSM loaded\n');
fprintf('  Template vertices: %d\n', num_vertices_template);
fprintf('  Available PCs: %d\n', length(eigenvalues));
fprintf('  Using %d PCs (%.1f%% variance)\n\n', CONFIG.num_pcs, sum(explained_variance(1:CONFIG.num_pcs)));

%% Load Clinical Case
fprintf('Loading clinical case: real_clinical_case.stl\n');
[vertices_damaged, faces_damaged] = load_stl_file(CONFIG.input_file);
num_vertices_damaged = size(vertices_damaged, 1);

fprintf('✓ Clinical case loaded\n');
fprintf('  Vertices: %d\n', num_vertices_damaged);
fprintf('  Faces: %d\n\n', size(faces_damaged, 1));

%% Remesh if needed
if num_vertices_damaged > 50000
    fprintf('⚠️  Dense mesh detected (%d vertices)\n', num_vertices_damaged);
    fprintf('Remeshing to match template density (this improves registration speed)...\n');

    [vertices_damaged, faces_damaged] = remesher(vertices_damaged, faces_damaged, 1.0, 1);
    num_vertices_damaged = size(vertices_damaged, 1);

    fprintf('✓ Remeshed to %d vertices\n', num_vertices_damaged);
    fprintf('  (Template has %d vertices)\n\n', num_vertices_template);
end

%% Registration to SSM Template Space
fprintf('═══════════════════════════════════════════════\n');
fprintf(' REGISTRATION TO SSM TEMPLATE SPACE\n');
fprintf('═══════════════════════════════════════════════\n\n');

% Step 1: Center both meshes
fprintf('Step 1: Centering meshes...\n');
centroid_template = mean(mean_shape);
centroid_damaged = mean(vertices_damaged);
vertices_damaged_centered = vertices_damaged - centroid_damaged;
mean_shape_centered = mean_shape - centroid_template;

% Step 2: Scale normalization
fprintf('Step 2: Normalizing scale...\n');
scale_template = mean(std(mean_shape_centered));
scale_damaged = mean(std(vertices_damaged_centered));
vertices_damaged_scaled = vertices_damaged_centered * (scale_template / scale_damaged);

% Step 3: Rigid ICP alignment
fprintf('Step 3: Rigid ICP alignment (50 iterations)...\n');
[vertices_damaged_aligned, ~] = rigid_icp(vertices_damaged_scaled, mean_shape_centered, 50);
vertices_damaged_aligned = vertices_damaged_aligned + centroid_template;
fprintf('  ✓ Rigid alignment complete\n');

% Step 4: Non-rigid registration
fprintf('Step 4: Non-rigid ICP for correspondence...\n');
if exist('nonrigidICPv2', 'file') == 2
    addpath('SSM');
    try
        vertices_registered = nonrigidICPv2(mean_shape, vertices_damaged_aligned, ...
            faces_template, faces_damaged, 20, 1);

        % Validate dimensions
        if size(vertices_registered, 1) ~= num_vertices_template
            fprintf('  ⚠️  nonrigidICPv2 returned %d vertices, expected %d\n', ...
                size(vertices_registered, 1), num_vertices_template);
            fprintf('  Falling back to nearest neighbor resampling...\n');
            vertices_registered = zeros(num_vertices_template, 3);
            for i = 1:num_vertices_template
                dists = sum((vertices_damaged_aligned - mean_shape(i,:)).^2, 2);
                [~, nearest_idx] = min(dists);
                vertices_registered(i, :) = vertices_damaged_aligned(nearest_idx, :);
            end
            fprintf('  ✓ Resampling complete\n');
        else
            fprintf('  ✓ Non-rigid ICP complete\n');
        end
    catch ME
        fprintf('  ⚠️  nonrigidICPv2 failed: %s\n', ME.message);
        fprintf('  Using nearest neighbor resampling...\n');
        vertices_registered = zeros(num_vertices_template, 3);
        for i = 1:num_vertices_template
            dists = sum((vertices_damaged_aligned - mean_shape(i,:)).^2, 2);
            [~, nearest_idx] = min(dists);
            vertices_registered(i, :) = vertices_damaged_aligned(nearest_idx, :);
        end
        fprintf('  ✓ Resampling complete\n');
    end
else
    fprintf('  ⚠️  nonrigidICPv2 not found, using nearest neighbor resampling\n');
    vertices_registered = zeros(num_vertices_template, 3);
    for i = 1:num_vertices_template
        dists = sum((vertices_damaged_aligned - mean_shape(i,:)).^2, 2);
        [~, nearest_idx] = min(dists);
        vertices_registered(i, :) = vertices_damaged_aligned(nearest_idx, :);
    end
    fprintf('  ✓ Resampling complete\n');
end

fprintf('\n✓ Registration complete\n\n');

%% SSM Reconstruction
fprintf('═══════════════════════════════════════════════\n');
fprintf(' SSM RECONSTRUCTION\n');
fprintf('═══════════════════════════════════════════════\n\n');

fprintf('Projecting onto %d principal components...\n', CONFIG.num_pcs);

% Center the registered shape
registered_centered = vertices_registered - mean_shape;
registered_vec = registered_centered(:);

% Project onto PC space
pc_scores = eigenvectors(:, 1:CONFIG.num_pcs)' * registered_vec;

fprintf('  PC scores computed\n');
fprintf('  Reconstructing...\n');

% Reconstruct from PC space
reconstructed_vec = eigenvectors(:, 1:CONFIG.num_pcs) * pc_scores;

% Reshape back to 3D coordinates
x_recon = reconstructed_vec(1:num_vertices_template);
y_recon = reconstructed_vec(num_vertices_template+1:2*num_vertices_template);
z_recon = reconstructed_vec(2*num_vertices_template+1:3*num_vertices_template);
reconstructed_shape = [x_recon, y_recon, z_recon] + mean_shape;

fprintf('\n✓ Reconstruction complete\n\n');

%% Qualitative Analysis
fprintf('═══════════════════════════════════════════════\n');
fprintf(' QUALITATIVE ANALYSIS\n');
fprintf('═══════════════════════════════════════════════\n\n');

% Compute difference: damaged vs reconstructed
diff_damaged_vs_recon = sqrt(sum((vertices_registered - reconstructed_shape).^2, 2));
rmse_damaged_vs_recon = sqrt(mean(diff_damaged_vs_recon.^2));

fprintf('Damaged → Reconstructed:\n');
fprintf('  • Mean distance: %.2f mm\n', rmse_damaged_vs_recon);
fprintf('  • Median distance: %.2f mm\n', median(diff_damaged_vs_recon));
fprintf('  • Max distance: %.2f mm\n', max(diff_damaged_vs_recon));
fprintf('  • 95th percentile: %.2f mm\n\n', prctile(diff_damaged_vs_recon, 95));

% Compute difference: damaged vs mean shape (shows how atypical the case is)
diff_damaged_vs_mean = sqrt(sum((vertices_registered - mean_shape).^2, 2));
rmse_damaged_vs_mean = sqrt(mean(diff_damaged_vs_mean.^2));

fprintf('Damaged → Mean Shape:\n');
fprintf('  • Mean distance: %.2f mm\n', rmse_damaged_vs_mean);
fprintf('  • Median distance: %.2f mm\n', median(diff_damaged_vs_mean));
fprintf('  • Max distance: %.2f mm\n', max(diff_damaged_vs_mean));
fprintf('  • 95th percentile: %.2f mm\n\n', prctile(diff_damaged_vs_mean, 95));

% Show top 5 PC contributions
fprintf('Reconstruction components (top 5 PCs):\n');
for i = 1:min(5, CONFIG.num_pcs)
    fprintf('  PC%d: score = %+.3f, explains %.1f%% variance\n', ...
        i, pc_scores(i), explained_variance(i));
end
fprintf('\n');

%% Export Results
fprintf('═══════════════════════════════════════════════\n');
fprintf(' EXPORTING RESULTS\n');
fprintf('═══════════════════════════════════════════════\n\n');

fprintf('Exporting STL files...\n');

% Export registered damaged
export_stl(vertices_registered, faces_template, ...
    fullfile(CONFIG.output_dir, 'damaged_registered.stl'));
fprintf('  ✓ damaged_registered.stl\n');

% Export reconstructed
export_stl(reconstructed_shape, faces_template, ...
    fullfile(CONFIG.output_dir, 'reconstructed.stl'));
fprintf('  ✓ reconstructed.stl (⭐ USE THIS FOR CLINICAL PLANNING)\n');

% Export mean shape for reference
export_stl(mean_shape, faces_template, ...
    fullfile(CONFIG.output_dir, 'mean_shape_reference.stl'));
fprintf('  ✓ mean_shape_reference.stl\n\n');

%% Generate Visualizations
fprintf('Generating visualizations...\n');

views_names = {'Frontal', 'Lateral', 'Occlusal'};
view_angles = {[0, 0], [90, 0], [0, 90]};

% Figure: Damaged - Reconstructed - Mean Shape - Differences
fig = figure('Position', [50, 50, 2000, 1600], 'Visible', 'off');

titles = {'(a) Damaged (Input)', ...
          '(b) Reconstructed (SSM)', ...
          '(c) Mean Shape (Reference)', ...
          '(d) Reconstruction Changes'};

shapes_to_plot = {vertices_registered, reconstructed_shape, mean_shape, vertices_registered};
face_data = {[0.9 0.6 0.6], [0.6 0.9 0.6], [0.7 0.7 0.7], diff_damaged_vs_recon};
use_heatmap = [false, false, false, true];

for panel = 1:4
    for view_idx = 1:3
        subplot_idx = (panel-1)*3 + view_idx;
        subplot(4, 3, subplot_idx);

        shape = shapes_to_plot{panel};

        if use_heatmap(panel)
            % Heatmap showing reconstruction changes
            trisurf(faces_template, shape(:,1), shape(:,2), shape(:,3), ...
                face_data{panel}, 'EdgeColor', 'none');
            colormap(gca, jet);
            caxis([0, 10]);  % 0-10mm range for clinical relevance
            if view_idx == 3
                cb = colorbar;
                ylabel(cb, 'Distance (mm)');
            end
        else
            % Solid mesh
            trisurf(faces_template, shape(:,1), shape(:,2), shape(:,3), ...
                'FaceColor', face_data{panel}, 'EdgeColor', 'none');
        end

        axis equal; axis off; lighting gouraud; camlight;
        view(view_angles{view_idx});

        if panel == 1
            title(views_names{view_idx}, 'FontSize', 11);
        end

        if view_idx == 1
            ylabel(titles{panel}, 'FontWeight', 'bold', 'FontSize', 12);
        end
    end
end

sgtitle(sprintf('Real Clinical Case Reconstruction - Mean Change: %.2f mm', rmse_damaged_vs_recon), ...
    'FontSize', 14, 'FontWeight', 'bold');

saveas(fig, fullfile(CONFIG.output_dir, 'reconstruction_visualization.png'));
saveas(fig, fullfile(CONFIG.output_dir, 'reconstruction_visualization.fig'));
print(fig, fullfile(CONFIG.output_dir, 'reconstruction_visualization_hires.png'), '-dpng', '-r300');
close(fig);

fprintf('  ✓ Visualization saved\n\n');

%% Generate Clinical Report
fprintf('Generating clinical report...\n');

report_file = fullfile(CONFIG.output_dir, 'clinical_report.txt');
fid = fopen(report_file, 'w');

fprintf(fid, '═══════════════════════════════════════════════════════════\n');
fprintf(fid, ' REAL CLINICAL CASE RECONSTRUCTION REPORT\n');
fprintf(fid, ' (No Ground Truth Available)\n');
fprintf(fid, '═══════════════════════════════════════════════════════════\n\n');
fprintf(fid, 'Date: %s\n\n', datestr(now));

fprintf(fid, 'INPUT:\n');
fprintf(fid, '  • Clinical case: real_clinical_case.stl\n');
fprintf(fid, '  • Original vertices: %d\n', num_vertices_damaged);
fprintf(fid, '  • Template vertices: %d\n\n', num_vertices_template);

fprintf(fid, 'SSM RECONSTRUCTION:\n');
fprintf(fid, '  • PCs used: %d\n', CONFIG.num_pcs);
fprintf(fid, '  • Variance captured: %.2f%%\n\n', sum(explained_variance(1:CONFIG.num_pcs)));

fprintf(fid, 'RECONSTRUCTION CHANGES:\n');
fprintf(fid, '  • Mean modification: %.2f mm\n', rmse_damaged_vs_recon);
fprintf(fid, '  • Median modification: %.2f mm\n', median(diff_damaged_vs_recon));
fprintf(fid, '  • Max modification: %.2f mm\n', max(diff_damaged_vs_recon));
fprintf(fid, '  • 95th percentile: %.2f mm\n\n', prctile(diff_damaged_vs_recon, 95));

fprintf(fid, 'DEVIATION FROM POPULATION MEAN:\n');
fprintf(fid, '  • Mean distance: %.2f mm\n', rmse_damaged_vs_mean);
fprintf(fid, '  • Median distance: %.2f mm\n', median(diff_damaged_vs_mean));
fprintf(fid, '  • Max distance: %.2f mm\n\n', max(diff_damaged_vs_mean));

fprintf(fid, 'TOP 5 PRINCIPAL COMPONENTS:\n');
for i = 1:min(5, CONFIG.num_pcs)
    fprintf(fid, '  • PC%d: score = %+.3f (%.1f%% variance)\n', ...
        i, pc_scores(i), explained_variance(i));
end
fprintf(fid, '\n');

fprintf(fid, 'CLINICAL INTERPRETATION:\n');
fprintf(fid, '  The SSM reconstruction represents the most plausible mandibular\n');
fprintf(fid, '  anatomy based on the population statistical model, given the\n');
fprintf(fid, '  observed defect/damage.\n\n');

if rmse_damaged_vs_recon < 3.0
    fprintf(fid, '  Reconstruction magnitude: MINOR (< 3 mm average change)\n');
    fprintf(fid, '  The SSM suggests minimal modification from the damaged state.\n');
elseif rmse_damaged_vs_recon < 6.0
    fprintf(fid, '  Reconstruction magnitude: MODERATE (3-6 mm average change)\n');
    fprintf(fid, '  The SSM proposes moderate anatomical changes.\n');
else
    fprintf(fid, '  Reconstruction magnitude: MAJOR (> 6 mm average change)\n');
    fprintf(fid, '  The SSM indicates significant anatomical reconstruction.\n');
    fprintf(fid, '  Consider reviewing heatmap for areas of major changes.\n');
end
fprintf(fid, '\n');

fprintf(fid, 'OUTPUT FILES:\n');
fprintf(fid, '  • damaged_registered.stl - Input (registered to SSM space)\n');
fprintf(fid, '  • reconstructed.stl - SSM reconstruction (USE FOR PLANNING)\n');
fprintf(fid, '  • mean_shape_reference.stl - Population mean shape\n');
fprintf(fid, '  • reconstruction_visualization.png - Visual comparison\n\n');

fprintf(fid, 'IMPORTANT NOTES:\n');
fprintf(fid, '  ⚠️  No ground truth available - accuracy cannot be quantified\n');
fprintf(fid, '  ⚠️  Reconstruction based on population statistics only\n');
fprintf(fid, '  ⚠️  Clinical judgment required for final planning\n');
fprintf(fid, '  ⚠️  Consider patient-specific factors not captured by SSM\n\n');

fprintf(fid, '═══════════════════════════════════════════════════════════\n');
fclose(fid);

fprintf('  ✓ Clinical report saved\n\n');

%% Summary
fprintf('╔════════════════════════════════════════════════════════════╗\n');
fprintf('║  RECONSTRUCTION COMPLETE ✓                                 ║\n');
fprintf('╚════════════════════════════════════════════════════════════╝\n\n');

fprintf('Results saved in: %s\n\n', CONFIG.output_dir);

fprintf('KEY OUTPUTS:\n');
fprintf('  📄 reconstructed.stl - USE THIS for clinical planning\n');
fprintf('  📊 reconstruction_visualization.png - Visual assessment\n');
fprintf('  📝 clinical_report.txt - Detailed analysis\n\n');

fprintf('RECONSTRUCTION SUMMARY:\n');
fprintf('  • Mean modification: %.2f mm\n', rmse_damaged_vs_recon);
fprintf('  • Deviation from population mean: %.2f mm\n', rmse_damaged_vs_mean);
fprintf('  • PCs used: %d (%.1f%% variance)\n\n', CONFIG.num_pcs, sum(explained_variance(1:CONFIG.num_pcs)));

fprintf('NEXT STEPS:\n');
fprintf('  1. Open reconstructed.stl in MeshLab or 3D Slicer\n');
fprintf('  2. Review heatmap in reconstruction_visualization.png\n');
fprintf('  3. Assess clinical feasibility of proposed reconstruction\n');
fprintf('  4. Consider patient-specific factors for final planning\n\n');

fprintf('⚠️  IMPORTANT: This reconstruction is based solely on population\n');
fprintf('   statistics. No ground truth available for accuracy validation.\n');
fprintf('   Clinical judgment is essential for final decision-making.\n\n');

%% ═════════════════════════════════════════════════════════════════════
%% HELPER FUNCTIONS
%% ═════════════════════════════════════════════════════════════════════

function [vertices, faces] = load_stl_file(filename)
    if exist('stlread', 'file') == 2
        tr = stlread(filename);
        vertices = tr.Points;
        faces = tr.ConnectivityList;
    elseif exist('READ_stl', 'file') == 2
        [vertices, faces] = READ_stl(filename);
    else
        [vertices, faces] = read_stl_ascii(filename);
    end
end

function [vertices_aligned, R] = rigid_icp(source, target, max_iter)
    vertices_aligned = source;
    for iter = 1:max_iter
        [~, idx] = pdist2(target, vertices_aligned, 'euclidean', 'Smallest', 1);
        [R, t] = compute_rigid_transform(vertices_aligned, target(idx, :));
        vertices_aligned = (R * vertices_aligned')' + t';
        if iter > 1 && norm(R - eye(3)) < 1e-6
            break;
        end
    end
end

function [R, t] = compute_rigid_transform(source, target)
    centroid_source = mean(source);
    centroid_target = mean(target);
    source_centered = source - centroid_source;
    target_centered = target - centroid_target;
    H = source_centered' * target_centered;
    [U, ~, V] = svd(H);
    R = V * U';
    if det(R) < 0
        V(:, 3) = -V(:, 3);
        R = V * U';
    end
    t = centroid_target' - R * centroid_source';
end

function export_stl(vertices, faces, filename)
    fid = fopen(filename, 'w');
    fprintf(fid, 'solid model\n');
    for i = 1:size(faces, 1)
        v1 = vertices(faces(i,1), :);
        v2 = vertices(faces(i,2), :);
        v3 = vertices(faces(i,3), :);
        edge1 = v2 - v1;
        edge2 = v3 - v1;
        normal = cross(edge1, edge2);
        normal = normal / (norm(normal) + eps);
        fprintf(fid, '  facet normal %.6e %.6e %.6e\n', normal(1), normal(2), normal(3));
        fprintf(fid, '    outer loop\n');
        fprintf(fid, '      vertex %.6e %.6e %.6e\n', v1(1), v1(2), v1(3));
        fprintf(fid, '      vertex %.6e %.6e %.6e\n', v2(1), v2(2), v2(3));
        fprintf(fid, '      vertex %.6e %.6e %.6e\n', v3(1), v3(2), v3(3));
        fprintf(fid, '    endloop\n');
        fprintf(fid, '  endfacet\n');
    end
    fprintf(fid, 'endsolid model\n');
    fclose(fid);
end

function [vertices, faces] = read_stl_ascii(filename)
    fid = fopen(filename, 'r');
    vertices = [];
    faces = [];
    vertex_count = 0;
    while ~feof(fid)
        line = fgetl(fid);
        if contains(line, 'vertex')
            parts = strsplit(strtrim(line));
            v = [str2double(parts{2}), str2double(parts{3}), str2double(parts{4})];
            vertices = [vertices; v];
            vertex_count = vertex_count + 1;
            if mod(vertex_count, 3) == 0
                faces = [faces; vertex_count-2, vertex_count-1, vertex_count];
            end
        end
    end
    fclose(fid);
end

%% END OF SCRIPT
