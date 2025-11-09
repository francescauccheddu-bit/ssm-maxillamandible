%% STATISTICAL SHAPE MODEL - OPTIMIZED MODULAR PIPELINE V2
%
% Optimized pipeline to build SSM with male + female samples
% Optimizations: Balanced speed/quality tradeoff vs V1
%
% NOVITÀ V2:
%   ✓ Gestione automatica maschi + femmine
%   ✓ ICP iterations differenziate (preliminary vs finali)
%   ✓ Remesh iterations: 3 (improved mesh quality)
%   ✓ GPA max iterations ridotte (10→5)
%   ✓ Remesh condizionale della mean shape
%   ✓ Metadati sesso salvati per analisi
%
% INPUT: STL files from Segmentazioni_Female and Segmentazioni_Male folders
%    ↓
% [FASE 1] Preprocessing (~15-30 min)
%    → Carica, centra, rimesha (3 iterations) → checkpoint
%    ↓
% [FASE 2] Registration (~1.5-3 ore) ⏰ PIÙ LUNGA
%    → Step 2.1: Trova best template (preliminary ICP)
%    → Step 2.2: Registrazione iterativa (ICP + GPA x 3)
%    → Tutti allineati con corrispondenza punto-a-punto → checkpoint
%    ↓
% [FASE 3] SSM Building (~5-10 min)
%    → PCA su coordinate
%    → Estrae eigenvalues, PC scores, mean shapes
%    → Salva metadati sesso → checkpoint
%    ↓
% [FASE 4] Organization (~1-2 min)
%    → Organizza file finali
%    → Statistiche sommario
%    ↓
% OUTPUT: SSM completo + analisi possibili
%
% UTILIZZO:
%   % Esecuzione completa (tutte le fasi)
%   PIPELINE_SSM_MODULAR_V2
%
%   % Esecuzione di singole fasi
%   PIPELINE_SSM_MODULAR_V2('start_from', 2)
%   PIPELINE_SSM_MODULAR_V2('only', 3)
%
% Author: Francesca Uccheddu, Università di Padova
% Date: 2025-11-07 (Optimized V2 with sex-specific analysis)

function PIPELINE_SSM_MODULAR_V2(varargin)

%% PARSE INPUT ARGUMENTS
p = inputParser;
addParameter(p, 'start_from', 1, @isnumeric);
addParameter(p, 'only', [], @isnumeric);
addParameter(p, 'force_recompute', false, @islogical);
parse(p, varargin{:});

start_phase = p.Results.start_from;
only_phase = p.Results.only;
force_recompute = p.Results.force_recompute;

%% CONFIGURATION
fprintf('\n========================================\n');
fprintf('SSM OPTIMIZED PIPELINE V2\n');
fprintf('========================================\n\n');

% Add path to SSM functions
addpath('SSM');

% Input configuration - BOTH male and female
INPUT_FOLDERS = {
    'Segmentazioni_Female', 'female';
    'Segmentazioni_Male', 'male'
};

% Output structure - V2 folders
OUTPUT_ROOT = 'output';
CHECKPOINT_FOLDER = fullfile(OUTPUT_ROOT, 'checkpoints');
ALIGNED_FOLDER = fullfile(OUTPUT_ROOT, 'aligned_models_v2');
SSM_RESULTS_FOLDER = fullfile(OUTPUT_ROOT, 'ssm_results_v2');
FINAL_RESULTS_FOLDER = fullfile(OUTPUT_ROOT, 'final_results_v2');
FINAL_EXPORTS_FOLDER = fullfile(OUTPUT_ROOT, 'final_results_v2', 'exports');

% Processing parameters - OPTIMIZED
CONFIG.remesh.edge_length = 1.0;                      % mm (1.0mm for valid RMSE measurements ≥1mm)
CONFIG.remesh.iterations = 3;                         % Improved mesh quality (reverted from 1)
CONFIG.registration.num_iterations = 3;               % Iterazioni registrazione
CONFIG.registration.icp_iterations_preliminary = 8;   % ⚡ NEW: preliminary (era 15)
CONFIG.registration.icp_iterations = 15;              % ICP finali (resta 15)
CONFIG.registration.icp_stiffness = 0;                % Pre-alignment flag
CONFIG.registration.gpa_max_iter = 5;                 % ⚡ OPTIMIZED: 10 → 5
CONFIG.registration.gpa_tolerance = 1e-6;             % GPA convergence
CONFIG.registration.remesh_every_n_iterations = 2;    % ⚡ NEW: remesh ogni 2 iter
CONFIG.ssm.num_modes_display = 3;

% Create folders
if ~exist(OUTPUT_ROOT, 'dir'), mkdir(OUTPUT_ROOT); end
folders = {CHECKPOINT_FOLDER, ALIGNED_FOLDER, SSM_RESULTS_FOLDER};
for i = 1:length(folders)
    if ~exist(folders{i}, 'dir'), mkdir(folders{i}); end
end

fprintf('Configuration V2 (OPTIMIZED):\n');
fprintf('  • Input folders: Female + Male\n');
fprintf('  • Checkpoint folder: %s\n', CHECKPOINT_FOLDER);
fprintf('  • Remesh edge length: %.1f mm\n', CONFIG.remesh.edge_length);
fprintf('  • Remesh iterations: %d (improved mesh quality)\n', CONFIG.remesh.iterations);
fprintf('  • Registration iterations: %d\n', CONFIG.registration.num_iterations);
fprintf('  • ICP preliminary: %d (OPTIMIZED: was 15)\n', CONFIG.registration.icp_iterations_preliminary);
fprintf('  • ICP iterations: %d\n', CONFIG.registration.icp_iterations);
fprintf('  • GPA max iterations: %d (OPTIMIZED: was 10)\n', CONFIG.registration.gpa_max_iter);
fprintf('  • Remesh mean every N iter: %d (OPTIMIZED: was 1)\n', CONFIG.registration.remesh_every_n_iterations);

if ~isempty(only_phase)
    fprintf('  • Mode: Execute ONLY phase %d\n', only_phase);
elseif start_phase > 1
    fprintf('  • Mode: Start from phase %d\n', start_phase);
else
    fprintf('  • Mode: Full pipeline execution\n');
end
fprintf('\n');

%% DETERMINE WHICH PHASES TO RUN
if ~isempty(only_phase)
    phases_to_run = only_phase;
else
    phases_to_run = start_phase:4;
end

%% MACRO-FASE 1: PREPROCESSING
if ismember(1, phases_to_run)
    checkpoint_file = fullfile(CHECKPOINT_FOLDER, 'phase1_preprocessing_v2.mat');

    if exist(checkpoint_file, 'file') && ~force_recompute
        fprintf('\n⚠️  Checkpoint found: %s\n', checkpoint_file);
        fprintf('   Skip Phase 1 or force recompute? [s=skip, r=recompute]: ');
        choice = input('', 's');
        if strcmpi(choice, 's')
            fprintf('   → Skipping Phase 1 (loading from checkpoint)\n\n');
            load(checkpoint_file, 'preprocessed_data');
        else
            preprocessed_data = phase1_preprocessing_v2(INPUT_FOLDERS, CONFIG);
            save(checkpoint_file, 'preprocessed_data', '-v7.3');
        end
    else
        preprocessed_data = phase1_preprocessing_v2(INPUT_FOLDERS, CONFIG);
        save(checkpoint_file, 'preprocessed_data', '-v7.3');
    end
else
    % Load from checkpoint
    checkpoint_file = fullfile(CHECKPOINT_FOLDER, 'phase1_preprocessing_v2.mat');
    if ~exist(checkpoint_file, 'file')
        error('Phase 1 checkpoint not found! Run Phase 1 first.');
    end
    load(checkpoint_file, 'preprocessed_data');
end

%% MACRO-FASE 2: REGISTRATION (OPTIMIZED)
if ismember(2, phases_to_run)
    checkpoint_file = fullfile(CHECKPOINT_FOLDER, 'phase2_registration_v2.mat');

    if exist(checkpoint_file, 'file') && ~force_recompute
        fprintf('\n⚠️  Checkpoint found: %s\n', checkpoint_file);
        fprintf('   Skip Phase 2 or force recompute? [s=skip, r=recompute]: ');
        choice = input('', 's');
        if strcmpi(choice, 's')
            fprintf('   → Skipping Phase 2 (loading from checkpoint)\n\n');
            load(checkpoint_file, 'registration_data');
        else
            registration_data = phase2_registration_v2(preprocessed_data, CONFIG, ALIGNED_FOLDER);
            save(checkpoint_file, 'registration_data', '-v7.3');
        end
    else
        registration_data = phase2_registration_v2(preprocessed_data, CONFIG, ALIGNED_FOLDER);
        save(checkpoint_file, 'registration_data', '-v7.3');
    end
else
    % Load from checkpoint
    checkpoint_file = fullfile(CHECKPOINT_FOLDER, 'phase2_registration_v2.mat');
    if ~exist(checkpoint_file, 'file')
        error('Phase 2 checkpoint not found! Run Phase 2 first.');
    end
    load(checkpoint_file, 'registration_data');
end

%% MACRO-FASE 3: SSM BUILDING (WITH SEX METADATA)
if ismember(3, phases_to_run)
    checkpoint_file = fullfile(CHECKPOINT_FOLDER, 'phase3_ssm_v2.mat');

    if exist(checkpoint_file, 'file') && ~force_recompute
        fprintf('\n⚠️  Checkpoint found: %s\n', checkpoint_file);
        fprintf('   Skip Phase 3 or force recompute? [s=skip, r=recompute]: ');
        choice = input('', 's');
        if strcmpi(choice, 's')
            fprintf('   → Skipping Phase 3 (loading from checkpoint)\n\n');
            load(checkpoint_file, 'ssm_data');
        else
            ssm_data = phase3_ssm_building_v2(registration_data, SSM_RESULTS_FOLDER);
            save(checkpoint_file, 'ssm_data', '-v7.3');
        end
    else
        ssm_data = phase3_ssm_building_v2(registration_data, SSM_RESULTS_FOLDER);
        save(checkpoint_file, 'ssm_data', '-v7.3');
    end
else
    % Load from checkpoint
    checkpoint_file = fullfile(CHECKPOINT_FOLDER, 'phase3_ssm_v2.mat');
    if ~exist(checkpoint_file, 'file')
        error('Phase 3 checkpoint not found! Run Phase 3 first.');
    end
    load(checkpoint_file, 'ssm_data');
end

%% MACRO-FASE 4: ORGANIZATION + SEX ANALYSIS
if ismember(4, phases_to_run)
    phase4_organization_v2(registration_data, ssm_data, ...
        ALIGNED_FOLDER, SSM_RESULTS_FOLDER, ...
        FINAL_RESULTS_FOLDER, FINAL_EXPORTS_FOLDER);
end

%% PIPELINE COMPLETED
fprintf('\n========================================\n');
fprintf('OPTIMIZED PIPELINE V2 COMPLETED!\n');
fprintf('========================================\n\n');

fprintf('Checkpoints saved in: %s/\n', CHECKPOINT_FOLDER);
fprintf('Final results saved in: %s/\n', FINAL_RESULTS_FOLDER);
fprintf('Aligned models exported in: %s/\n', FINAL_EXPORTS_FOLDER);
fprintf('\n');

fprintf('💡 TIP: To run specific phases:\n');
fprintf('   PIPELINE_SSM_MODULAR_V2(''start_from'', 2)\n');
fprintf('   PIPELINE_SSM_MODULAR_V2(''only'', 3)\n');
fprintf('   PIPELINE_SSM_MODULAR_V2(''force_recompute'', true)\n');
fprintf('\n');

fprintf('📊 Next steps:\n');
fprintf('   1. Run analyze_shape_variation.m to check variance distribution\n');
fprintf('   2. Run analyze_sex_differences_v2.m to compare male vs female\n');
fprintf('\n');

end


%% ============================================================================
%  FASE 1: PREPROCESSING (MALE + FEMALE)
%% ============================================================================
function data = phase1_preprocessing_v2(input_folders, config)
    fprintf('\n========================================\n');
    fprintf('FASE 1: PREPROCESSING (OPTIMIZED V2)\n');
    fprintf('========================================\n\n');
    fprintf('Tasks:\n');
    fprintf('  • Import STL files from multiple folders\n');
    fprintf('  • Track sex metadata\n');
    fprintf('  • Center meshes at origin\n');
    fprintf('  • Isotropic remeshing (edge length: %.1f mm, iterations: %d)\n\n', ...
        config.remesh.edge_length, config.remesh.iterations);

    % Initialize storage
    all_filenames = {};
    all_vertices = {};
    all_faces = {};
    all_sex_labels = {};  % 'female' or 'male'

    total_files = 0;

    % Process each input folder
    for folder_idx = 1:size(input_folders, 1)
        folder_name = input_folders{folder_idx, 1};
        sex_label = input_folders{folder_idx, 2};

        fprintf('Processing folder: %s (sex: %s)\n', folder_name, sex_label);
        fprintf('---------------------------------------------\n');

        % Get list of STL files
        stl_files = dir(fullfile(folder_name, '*.stl'));
        num_files = length(stl_files);

        if num_files == 0
            fprintf('⚠️  WARNING: No STL files found in %s\n\n', folder_name);
            continue;
        end

        fprintf('Found %d STL files\n\n', num_files);

        % Process each file
        tic;
        for i = 1:num_files
            file_path = fullfile(folder_name, stl_files(i).name);
            fprintf('[%d/%d] Processing: %s\n', i, num_files, stl_files(i).name);

            % Import STL
            TR = stlread(file_path);
            vertices = TR.Points;
            faces = TR.ConnectivityList;

            % Center at origin
            vertices = vertices - mean(vertices, 1);

            % Remesh (OPTIMIZED: fewer iterations)
            [vertices, faces] = remesher(vertices, faces, ...
                config.remesh.edge_length, config.remesh.iterations);

            % Store
            all_vertices{end+1} = vertices;
            all_faces{end+1} = faces;
            all_filenames{end+1} = stl_files(i).name;
            all_sex_labels{end+1} = sex_label;

            fprintf('        → Vertices: %d, Faces: %d, Sex: %s\n', ...
                size(vertices,1), size(faces,1), sex_label);
        end
        elapsed = toc;

        total_files = total_files + num_files;
        fprintf('\n✓ Folder completed in %.1f seconds\n\n', elapsed);
    end

    % Prepare output data
    data.num_models = total_files;
    data.filenames = all_filenames';
    data.vertices = all_vertices';
    data.faces = all_faces';
    data.sex_labels = all_sex_labels';  % NEW: sex metadata

    % Count by sex
    num_female = sum(strcmp(data.sex_labels, 'female'));
    num_male = sum(strcmp(data.sex_labels, 'male'));

    fprintf('\n✓ Phase 1 completed\n');
    fprintf('  → Total models: %d (Female: %d, Male: %d)\n', total_files, num_female, num_male);
    fprintf('  → Checkpoint saved: checkpoints/phase1_preprocessing_v2.mat\n');
end


%% ============================================================================
%  FASE 2: REGISTRATION (OPTIMIZED)
%% ============================================================================
function data = phase2_registration_v2(preprocessed_data, config, output_folder)
    fprintf('\n========================================\n');
    fprintf('FASE 2: ITERATIVE REGISTRATION (OPTIMIZED V2)\n');
    fprintf('========================================\n\n');
    fprintf('Strategy:\n');
    fprintf('  • Initial registration to find best template\n');
    fprintf('  • %d iterations: register → GPA → mean → remesh (conditional)\n', ...
        config.registration.num_iterations);
    fprintf('  • OPTIMIZATIONS:\n');
    fprintf('    - ICP preliminary: %d iterations (was 15)\n', config.registration.icp_iterations_preliminary);
    fprintf('    - ICP final: %d iterations\n', config.registration.icp_iterations);
    fprintf('    - GPA max: %d iterations (was 10)\n', config.registration.gpa_max_iter);
    fprintf('    - Remesh mean: every %d iterations (was 1)\n\n', config.registration.remesh_every_n_iterations);

    num_files = preprocessed_data.num_models;
    all_vertices = preprocessed_data.vertices;
    all_faces = preprocessed_data.faces;

    % Start timing
    tic;

    % -------------------------------------------------------------------------
    % STEP 2.1: Find best template (OPTIMIZED ICP)
    % -------------------------------------------------------------------------
    fprintf('Step 2.1: Finding best template (OPTIMIZED)\n');
    fprintf('---------------------------------------------\n');

    initial_template_idx = 1;
    template_vertices = all_vertices{initial_template_idx};
    template_faces = all_faces{initial_template_idx};

    fprintf('Using model #%d as initial template\n', initial_template_idx);

    % Preliminary registration with FEWER ICP iterations
    preliminary_aligned = cell(num_files, 1);
    preliminary_aligned{initial_template_idx} = template_vertices;

    for i = 1:num_files
        if i == initial_template_idx
            fprintf('[%d/%d] Template (skipped)\n', i, num_files);
            continue;
        end

        fprintf('[%d/%d] Preliminary registration (ICP: %d iter)...\n', ...
            i, num_files, config.registration.icp_iterations_preliminary);

        % ⚡ OPTIMIZATION: Use fewer ICP iterations for preliminary
        [registered_vertices, ~, ~] = nonrigidICPv2(...
            all_vertices{i}, template_vertices, ...
            all_faces{i}, template_faces, ...
            config.registration.icp_iterations_preliminary, ...  % OPTIMIZED
            config.registration.icp_stiffness);

        preliminary_aligned{i} = registered_vertices;
    end

    % Compute mean and find best template
    num_vertices = size(template_vertices, 1);
    mean_vertices = zeros(num_vertices, 3);
    for i = 1:num_files
        mean_vertices = mean_vertices + preliminary_aligned{i};
    end
    mean_vertices = mean_vertices / num_files;

    errors = zeros(num_files, 1);
    for i = 1:num_files
        diff = preliminary_aligned{i} - mean_vertices;
        errors(i) = sqrt(mean(sum(diff.^2, 2)));
    end

    [~, best_template_idx] = min(errors);
    fprintf('        → Best template: model #%d (RMS: %.4f mm)\n\n', ...
        best_template_idx, errors(best_template_idx));

    % -------------------------------------------------------------------------
    % STEP 2.2: Iterative registration (OPTIMIZED)
    % -------------------------------------------------------------------------
    fprintf('Step 2.2: Iterative registration with optimized GPA\n');
    fprintf('---------------------------------------------\n');

    template_vertices = all_vertices{best_template_idx};
    template_faces = all_faces{best_template_idx};
    num_vertices = size(template_vertices, 1);

    aligned_vertices = cell(num_files, 1);

    for iter = 1:config.registration.num_iterations
        fprintf('\nIteration %d/%d:\n', iter, config.registration.num_iterations);

        % Register all to current template (FULL ICP iterations)
        for i = 1:num_files
            fprintf('  [%d/%d] Registering (ICP: %d iter)...\n', ...
                i, num_files, config.registration.icp_iterations);

            [registered_vertices, ~, ~] = nonrigidICPv2(...
                all_vertices{i}, template_vertices, ...
                all_faces{i}, template_faces, ...
                config.registration.icp_iterations, ...  % FULL iterations
                config.registration.icp_stiffness);

            aligned_vertices{i} = registered_vertices;
        end

        % Apply GPA (OPTIMIZED)
        fprintf('  → Applying GPA (max %d iter)...\n', config.registration.gpa_max_iter);
        current_num_vertices = size(template_vertices, 1);

        X_gpa = zeros(current_num_vertices * 3, num_files);
        for i = 1:num_files
            X_gpa(:, i) = aligned_vertices{i}(:);
        end

        mean_shape_vec = mean(X_gpa, 2);

        % ⚡ OPTIMIZATION: Reduced GPA iterations
        for gpa_iter = 1:config.registration.gpa_max_iter
            X_aligned_gpa = zeros(size(X_gpa));
            for i = 1:num_files
                source = reshape(X_gpa(:, i), current_num_vertices, 3);
                target = reshape(mean_shape_vec, current_num_vertices, 3);
                [~, aligned, ~] = procrustes(target, source, 'Scaling', false);
                X_aligned_gpa(:, i) = aligned(:);
            end
            new_mean = mean(X_aligned_gpa, 2);
            change = norm(new_mean - mean_shape_vec) / norm(mean_shape_vec);
            if change < config.registration.gpa_tolerance
                mean_shape_vec = new_mean;
                X_gpa = X_aligned_gpa;
                break;
            end
            mean_shape_vec = new_mean;
            X_gpa = X_aligned_gpa;
        end

        % Update aligned vertices with GPA results
        for i = 1:num_files
            aligned_vertices{i} = reshape(X_gpa(:, i), current_num_vertices, 3);
        end
        fprintf('  → GPA converged in %d iterations\n', min(gpa_iter, config.registration.gpa_max_iter));

        % ⚡ OPTIMIZATION: Conditional remeshing
        should_remesh = (iter < config.registration.num_iterations) && ...
                        (mod(iter, config.registration.remesh_every_n_iterations) == 0);

        if should_remesh
            mean_vertices = reshape(mean_shape_vec, current_num_vertices, 3);
            fprintf('  → Remeshing mean shape (every %d iter)...\n', ...
                config.registration.remesh_every_n_iterations);
            [mean_vertices, mean_faces] = remesher(mean_vertices, template_faces, ...
                config.remesh.edge_length, 1);

            template_vertices = mean_vertices;
            template_faces = mean_faces;
            fprintf('  → Template updated for next iteration\n');
        else
            fprintf('  → Skipping remesh (not needed this iteration)\n');
        end
    end

    elapsed = toc;

    % Export aligned STL files
    fprintf('\nExporting aligned models...\n');
    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end

    for i = 1:num_files
        vertices = aligned_vertices{i};
        surface_mesh = triangulation(template_faces, vertices);

        % Extract original filename and create new name with ID + M/F
        original_name = preprocessed_data.filenames{i};
        [~, base_name, ~] = fileparts(original_name);

        % Extract ID code from original filename (e.g., "Model_123" -> "123")
        % This handles various naming patterns
        id_match = regexp(base_name, '\d+', 'match');
        if ~isempty(id_match)
            id_code = id_match{end};  % Take last number found
        else
            id_code = sprintf('%02d', i);  % Fallback to sequential number
        end

        % Get sex label (M/F)
        sex_label = preprocessed_data.sex_labels{i};
        if strcmp(sex_label, 'Female')
            sex_code = 'F';
        else
            sex_code = 'M';
        end

        % Create output filename: {ID}_{M/F}_aligned.stl
        output_file = fullfile(output_folder, sprintf('%s_%s_aligned.stl', id_code, sex_code));
        stlwrite(surface_mesh, output_file);
    end
    fprintf('        → Exported %d aligned STL files with ID + M/F naming\n', num_files);

    % Prepare output data
    data.num_models = num_files;
    data.filenames = preprocessed_data.filenames;
    data.sex_labels = preprocessed_data.sex_labels;  % Preserve sex metadata
    data.aligned_vertices = aligned_vertices;
    data.faces = template_faces;
    data.best_template_idx = best_template_idx;

    fprintf('\n✓ Phase 2 completed in %.1f minutes\n', elapsed/60);
    fprintf('  → Checkpoint saved: checkpoints/phase2_registration_v2.mat\n');
    fprintf('  → Aligned models exported: %s/\n', output_folder);
end


%% ============================================================================
%  FASE 3: SSM BUILDING (WITH SEX METADATA)
%% ============================================================================
function data = phase3_ssm_building_v2(registration_data, output_folder)
    fprintf('\n========================================\n');
    fprintf('FASE 3: SSM BUILDING (V2 WITH SEX DATA)\n');
    fprintf('========================================\n\n');

    num_files = registration_data.num_models;
    aligned_vertices = registration_data.aligned_vertices;
    faces = registration_data.faces;

    % FIX: Handle old checkpoints without sex_labels
    if isfield(registration_data, 'sex_labels')
        sex_labels = registration_data.sex_labels;
    else
        fprintf('⚠️  WARNING: sex_labels not found in Phase 2 checkpoint\n');
        fprintf('   Attempting to load from Phase 1 checkpoint...\n');
        checkpoint_phase1 = fullfile('output', 'checkpoints', 'phase1_preprocessing_v2.mat');
        if exist(checkpoint_phase1, 'file')
            temp_data = load(checkpoint_phase1, 'preprocessed_data');
            if isfield(temp_data.preprocessed_data, 'sex_labels')
                sex_labels = temp_data.preprocessed_data.sex_labels;
                fprintf('   ✓ sex_labels loaded from Phase 1\n\n');
            else
                fprintf('   ⚠️  sex_labels not in Phase 1 either (old checkpoint)\n');
                fprintf('   Reconstructing sex_labels from filenames...\n');
                sex_labels = reconstruct_sex_labels_from_filenames(registration_data.filenames);
                fprintf('   ✓ sex_labels reconstructed: %d female, %d male\n\n', ...
                    sum(strcmp(sex_labels, 'female')), sum(strcmp(sex_labels, 'male')));
            end
        else
            fprintf('   Phase 1 checkpoint not found.\n');
            fprintf('   Reconstructing sex_labels from filenames...\n');
            sex_labels = reconstruct_sex_labels_from_filenames(registration_data.filenames);
            fprintf('   ✓ sex_labels reconstructed: %d female, %d male\n\n', ...
                sum(strcmp(sex_labels, 'female')), sum(strcmp(sex_labels, 'male')));
        end
    end

    % Create coordinate matrices (generic names - works for any anatomy)
    num_vertices = size(aligned_vertices{1}, 1);
    Xdata = zeros(num_files, num_vertices);
    Ydata = zeros(num_files, num_vertices);
    Zdata = zeros(num_files, num_vertices);

    for i = 1:num_files
        Xdata(i, :) = aligned_vertices{i}(:, 1);
        Ydata(i, :) = aligned_vertices{i}(:, 2);
        Zdata(i, :) = aligned_vertices{i}(:, 3);
    end

    % Build SSM
    fprintf('Computing PCA...\n');
    tic;
    [shape_modes, eigenvalues, eigenvectors, mean_shape, pc_cumulative, modes] = ...
        SSMbuilder(Xdata', Ydata', Zdata');
    elapsed = toc;

    fprintf('        → %d principal components extracted\n', size(shape_modes, 2));
    fprintf('        → Cumulative variance: %.2f%%\n', pc_cumulative(end)*100);

    % Export mean shape
    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end

    mean_shape_vertices = reshape(mean_shape, [], 3);
    TR_mean = triangulation(faces, mean_shape_vertices);
    mean_shape_file = fullfile(output_folder, 'mean_shape_mandible_v2.stl');
    stlwrite(TR_mean, mean_shape_file);
    fprintf('        → Mean shape exported: %s\n', mean_shape_file);

    % Calculate explained variance
    total_variance = sum(eigenvalues);
    explained = (eigenvalues / total_variance) * 100;

    % Compute sex-specific mean shapes
    fprintf('\nComputing sex-specific mean shapes...\n');

    female_idx = strcmp(sex_labels, 'female');
    male_idx = strcmp(sex_labels, 'male');

    num_female = sum(female_idx);
    num_male = sum(male_idx);

    fprintf('  • Female samples: %d\n', num_female);
    fprintf('  • Male samples: %d\n', num_male);

    % FIX: Apply same normalization (reallign2) used by SSMbuilder
    % This ensures sex-specific means are comparable to global mean
    fprintf('  • Applying normalization (reallign2) to data...\n');
    [Xnorm, Ynorm, Znorm] = reallign2(Xdata', Ydata', Zdata', 'whetherScaling', true);
    Xnorm = Xnorm';  % Transpose back to (num_files x num_vertices)
    Ynorm = Ynorm';
    Znorm = Znorm';

    if num_female > 0
        mean_x = mean(Xnorm(female_idx, :), 1);
        mean_y = mean(Ynorm(female_idx, :), 1);
        mean_z = mean(Znorm(female_idx, :), 1);
        female_shape_vertices = [mean_x', mean_y', mean_z'];
        TR_female = triangulation(faces, female_shape_vertices);
        female_file = fullfile(output_folder, 'mean_shape_female_v2.stl');
        stlwrite(TR_female, female_file);
        fprintf('  → Female mean shape exported\n');
    end

    if num_male > 0
        mean_x = mean(Xnorm(male_idx, :), 1);
        mean_y = mean(Ynorm(male_idx, :), 1);
        mean_z = mean(Znorm(male_idx, :), 1);
        male_shape_vertices = [mean_x', mean_y', mean_z'];
        TR_male = triangulation(faces, male_shape_vertices);
        male_file = fullfile(output_folder, 'mean_shape_male_v2.stl');
        stlwrite(TR_male, male_file);
        fprintf('  → Male mean shape exported\n');
    end

    % CRITICAL: Save BOTH original and normalized data
    % The SSM (MEAN, ssmV) was built on normalized data, so we need both:
    % - Original data for visualization/export
    % - Normalized data for reconstruction and analysis
    fprintf('  • Saving both original and normalized data to checkpoint...\n');

    % Normalize data using same method as SSMbuilder
    [Xdata_norm, Ydata_norm, Zdata_norm] = reallign2(Xdata', Ydata', Zdata', 'whetherScaling', true);

    % Prepare output data (generic names for any anatomy)
    data.Xdata = Xdata';  % Original (non-normalized)
    data.Ydata = Ydata';
    data.Zdata = Zdata';
    data.Xdata_norm = Xdata_norm;  % NEW: Normalized (matches MEAN/ssmV coordinate space)
    data.Ydata_norm = Ydata_norm;
    data.Zdata_norm = Zdata_norm;
    data.Fdata = faces;
    data.ssmV = shape_modes;
    data.MEAN = mean_shape;
    data.PCcum = pc_cumulative;
    data.eigenvalues = eigenvalues;
    data.explained = explained;
    data.filenames = registration_data.filenames;
    data.sex_labels = sex_labels;  % NEW: preserve sex metadata
    data.female_idx = female_idx;
    data.male_idx = male_idx;

    fprintf('\n✓ Phase 3 completed in %.1f seconds\n', elapsed);
    fprintf('  → Checkpoint saved: checkpoints/phase3_ssm_v2.mat\n');
    fprintf('  → Mean shapes exported: %s\n', output_folder);
end


%% ============================================================================
%  FASE 4: ORGANIZATION + SEX ANALYSIS
%% ============================================================================
function phase4_organization_v2(registration_data, ssm_data, ...
    aligned_folder, ssm_folder, final_results_folder, final_exports_folder)

    fprintf('\n========================================\n');
    fprintf('FASE 4: FINAL ORGANIZATION + SEX ANALYSIS\n');
    fprintf('========================================\n\n');

    % Create final folders
    if ~exist(final_results_folder, 'dir')
        mkdir(final_results_folder);
    end
    if ~exist(final_exports_folder, 'dir')
        mkdir(final_exports_folder);
    end

    % Save standard .mat files
    fprintf('Saving standard format files...\n');

    % ResultsMandibleComplete_v2.mat (for alignment data)
    Xdata = ssm_data.Xdata;
    Ydata = ssm_data.Ydata;
    Zdata = ssm_data.Zdata;
    Fdata = ssm_data.Fdata;
    sex_labels = ssm_data.sex_labels;  % NEW

    results_file = fullfile(final_results_folder, 'ResultsMandibleComplete_v2.mat');
    save(results_file, 'Xdata', 'Ydata', 'Zdata', 'Fdata', 'sex_labels', '-v7.3');
    fprintf('  ✓ %s\n', results_file);

    % ModelMandiboleComplete.mat (for SSM model)
    ssmV = ssm_data.ssmV;
    MEAN = ssm_data.MEAN;
    PCcum = ssm_data.PCcum;
    latent = ssm_data.eigenvalues;
    explained = ssm_data.explained;
    female_idx = ssm_data.female_idx;  % NEW
    male_idx = ssm_data.male_idx;      % NEW

    model_file = fullfile(final_results_folder, 'ModelMandibleComplete_v2.mat');
    save(model_file, 'ssmV', 'MEAN', 'Fdata', 'PCcum', 'latent', 'explained', ...
         'sex_labels', 'female_idx', 'male_idx', '-v7.3');
    fprintf('  ✓ %s\n', model_file);

    % Copy mean shapes only (aligned models stay in aligned_models_v2/)
    fprintf('\nCopying mean shapes...\n');
    mean_files = dir(fullfile(ssm_folder, 'mean_shape*.stl'));
    for i = 1:length(mean_files)
        src = fullfile(ssm_folder, mean_files(i).name);
        dst = fullfile(final_exports_folder, mean_files(i).name);
        copyfile(src, dst);
    end
    fprintf('  ✓ Copied %d mean shape files\n', length(mean_files));

    % Summary statistics
    fprintf('\n========================================\n');
    fprintf('SUMMARY STATISTICS\n');
    fprintf('========================================\n');
    fprintf('Total samples: %d\n', length(sex_labels));
    fprintf('  • Female: %d\n', sum(strcmp(sex_labels, 'female')));
    fprintf('  • Male: %d\n', sum(strcmp(sex_labels, 'male')));
    fprintf('\nVariance explained by first 3 PCs: %.2f%%\n', sum(explained(1:min(3,length(explained)))));
    fprintf('PCs needed for 90%% variance: %d\n', find(PCcum >= 0.90, 1));
    fprintf('PCs needed for 95%% variance: %d\n', find(PCcum >= 0.95, 1));

    fprintf('\n✓ Phase 4 completed\n');
    fprintf('\nFinal structure:\n');
    fprintf('  %s/\n', final_results_folder);
    fprintf('    ├── ResultsMandibleComplete_v2.mat (aligned data + sex)\n');
    fprintf('    └── ModelMandibleComplete_v2.mat (SSM model + sex)\n');
    fprintf('  %s/ (mean shapes only)\n', final_exports_folder);
    fprintf('    ├── mean_shape_mandible_v2.stl\n');
    fprintf('    ├── mean_shape_female_v2.stl\n');
    fprintf('    └── mean_shape_male_v2.stl\n');
    fprintf('\n  Aligned models: %s/ (40 files)\n', aligned_folder);
end


%% ============================================================================
%  HELPER FUNCTION: Reconstruct sex_labels from filenames
%% ============================================================================
function sex_labels = reconstruct_sex_labels_from_filenames(filenames)
    % Reconstruct sex_labels by checking which input folder contains each file
    % Used when old checkpoints don't have sex_labels field
    % IMPORTANT: Uses filenames to maintain correct order

    INPUT_FOLDERS = {
        'Segmentazioni_Female', 'female';
        'Segmentazioni_Male', 'male'
    };

    num_files = length(filenames);
    sex_labels = cell(num_files, 1);

    % For each filename, find which folder it belongs to
    for i = 1:num_files
        filename = filenames{i};
        found = false;

        for folder_idx = 1:size(INPUT_FOLDERS, 1)
            folder_name = INPUT_FOLDERS{folder_idx, 1};
            sex_label = INPUT_FOLDERS{folder_idx, 2};

            file_path = fullfile(folder_name, filename);
            if exist(file_path, 'file')
                sex_labels{i} = sex_label;
                found = true;
                break;
            end
        end

        if ~found
            fprintf('   ⚠️  WARNING: File not found in any input folder: %s\n', filename);
            fprintf('      Searched in: ');
            for folder_idx = 1:size(INPUT_FOLDERS, 1)
                fprintf('%s ', INPUT_FOLDERS{folder_idx, 1});
            end
            fprintf('\n');
            fprintf('      Skipping this file (no sex label assigned)\n');
            sex_labels{i} = 'unknown';
        end
    end

    % Remove unknown labels
    unknown_count = sum(strcmp(sex_labels, 'unknown'));
    if unknown_count > 0
        fprintf('\n   ⚠️  WARNING: %d files not found in input folders!\n', unknown_count);
        fprintf('      Please check your folder structure.\n\n');
    end
end
