% ANALYZE_SSM_RESULTS Script completo per analizzare i risultati SSM
%
% Questo script esegue:
% 1. Visualizzazione della distribuzione della varianza tra i PC
% 2. Generazione di file STL per PC1, PC2, PC3 a ±3SD
%
% Usage:
%   Modificare i parametri nella sezione CONFIGURATION e poi eseguire
%
% Output:
%   - output/variance_analysis/       : Grafici e statistiche sulla varianza
%   - output/pc_morphology/           : File STL delle variazioni morfologiche
%
% Example:
%   >> analyze_ssm_results

%% CONFIGURATION
ssm_model_path = 'data/output/models/ssm_model.mat';
variance_output_dir = 'data/output/variance_analysis';
stl_output_dir = 'data/output/pc_morphology';

% PCs to generate (default: first 3)
pcs_to_generate = [1, 2, 3];

% Standard deviation multiplier (default: 3)
std_multiplier = 3;

%% CHECK FILE EXISTENCE
fprintf('========================================\n');
fprintf('SSM RESULTS ANALYSIS\n');
fprintf('========================================\n\n');

if ~exist(ssm_model_path, 'file')
    error('SSM model file not found: %s\nPlease run the pipeline first.', ssm_model_path);
end

fprintf('SSM model found: %s\n\n', ssm_model_path);

%% STEP 1: VISUALIZE VARIANCE DISTRIBUTION
fprintf('========================================\n');
fprintf('STEP 1: VARIANCE DISTRIBUTION ANALYSIS\n');
fprintf('========================================\n\n');

try
    visualize_variance_distribution(ssm_model_path);
    fprintf('\n[OK] Variance distribution analysis completed!\n\n');
catch ME
    fprintf('\n[ERROR] Variance distribution analysis failed:\n');
    fprintf('  %s\n\n', ME.message);
    rethrow(ME);
end

%% STEP 2: GENERATE PC MORPHOLOGY STLs
fprintf('========================================\n');
fprintf('STEP 2: PC MORPHOLOGY STL GENERATION\n');
fprintf('========================================\n\n');

try
    generate_pc_morphology_stls(ssm_model_path, stl_output_dir, pcs_to_generate, std_multiplier);
    fprintf('\n[OK] PC morphology STL generation completed!\n\n');
catch ME
    fprintf('\n[ERROR] PC morphology STL generation failed:\n');
    fprintf('  %s\n\n', ME.message);
    rethrow(ME);
end

%% SUMMARY
fprintf('========================================\n');
fprintf('ANALYSIS COMPLETED SUCCESSFULLY!\n');
fprintf('========================================\n\n');

fprintf('Results:\n');
fprintf('  1. Variance analysis:   %s\n', variance_output_dir);
fprintf('  2. PC morphology STLs:  %s\n', stl_output_dir);

fprintf('\nNext steps:\n');
fprintf('  - Review variance distribution plots in %s\n', variance_output_dir);
fprintf('  - Load STL files in 3D viewer (MeshLab, 3D Slicer, etc.) to inspect morphological variations\n');
fprintf('  - Compare mean_shape.stl with PC variations to understand shape changes\n\n');

fprintf('To view STL files, you can use:\n');
fprintf('  - MeshLab (free, cross-platform)\n');
fprintf('  - 3D Slicer (free, medical imaging)\n');
fprintf('  - Any other STL viewer\n\n');

fprintf('========================================\n\n');
