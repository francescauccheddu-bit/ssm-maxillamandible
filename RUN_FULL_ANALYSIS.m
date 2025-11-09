%% RUN_FULL_ANALYSIS - Complete SSM Pipeline + Statistical Analysis + Clinical Reconstruction
%
% This script runs the entire analysis pipeline and saves all console output
% to prevent data loss if clc is accidentally executed.
%
% OUTPUT FILES:
%   - output/results/pipeline_log_[timestamp].txt    : Full pipeline console output
%   - output/results/analysis_log_[timestamp].txt    : Statistical analysis output
%   - output/results/clinical_log_[timestamp].txt    : Clinical reconstruction output (optional)
%   - SSM/ssm_female_mandible.mat                    : SSM model
%   - output/results/                                : Analysis results and figures
%   - output/results/clinical_reconstruction/        : Clinical case results (if available)
%
% USAGE:
%   Run this script from MATLAB command window or press F5
%
% OPTIONAL CLINICAL RECONSTRUCTION:
%   Place real_clinical_case.stl in input_cases/ to automatically run reconstruction
%
% NOTES:
%   - Input STL files should already be filtered (excluded models removed)
%   - No artifact checking is performed (assumes clean input)
%   - Process may take 30+ minutes depending on dataset size
%
% Created: November 8, 2025
% Updated: November 8, 2025 - Added clinical reconstruction integration

%% Setup
clear; clc; close all;

% Create timestamp for log files
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');

% Ensure output directories exist
if ~exist('output', 'dir')
    mkdir('output');
end
if ~exist(fullfile('output', 'results'), 'dir')
    mkdir(fullfile('output', 'results'));
end

%% STEP 1: Run SSM Pipeline
fprintf('\n');
fprintf('========================================================================\n');
fprintf('STEP 1/3: BUILDING STATISTICAL SHAPE MODEL\n');
fprintf('========================================================================\n');
fprintf('Started at: %s\n', datestr(now));
fprintf('Log file: output/results/pipeline_log_%s.txt\n\n', timestamp);

% Start diary for pipeline
pipeline_log = fullfile('output', 'results', sprintf('pipeline_log_%s.txt', timestamp));
diary(pipeline_log);

try
    % Run the SSM pipeline
    fprintf('Running PIPELINE_SSM_MODULAR_V2.m...\n');
    PIPELINE_SSM_MODULAR_V2;
    fprintf('\n✓ SSM Pipeline completed successfully!\n\n');
    pipeline_success = true;
catch ME
    fprintf('\n✗ ERROR in SSM Pipeline:\n');
    fprintf('   %s\n', ME.message);
    pipeline_success = false;
end

% Stop diary for pipeline
diary off;

%% STEP 2: Run Statistical Analysis
if pipeline_success
    fprintf('\n');
    fprintf('========================================================================\n');
    fprintf('STEP 2/3: STATISTICAL ANALYSIS (Sex Differences)\n');
    fprintf('========================================================================\n');
    fprintf('Started at: %s\n', datestr(now));
    fprintf('Log file: output/results/analysis_log_%s.txt\n\n', timestamp);

    % Start diary for analysis
    analysis_log = fullfile('output', 'results', sprintf('analysis_log_%s.txt', timestamp));
    diary(analysis_log);

    try
        % Run the manuscript analysis
        fprintf('Running MANUSCRIPT_SSM_MANDIBLE_ANALYSIS.m...\n');
        MANUSCRIPT_SSM_MANDIBLE_ANALYSIS;
        fprintf('\n✓ Statistical analysis completed successfully!\n\n');
        analysis_success = true;
    catch ME
        fprintf('\n✗ ERROR in Statistical Analysis:\n');
        fprintf('   %s\n', ME.message);
        analysis_success = false;
    end

    % Stop diary for analysis
    diary off;
else
    fprintf('⚠ Skipping statistical analysis due to pipeline error.\n');
    analysis_success = false;
end

%% STEP 3: Run Clinical Case Reconstruction (Optional)
clinical_success = false;
clinical_log = '';

% Check if clinical case file exists
clinical_case_file = fullfile('input_cases', 'real_clinical_case.stl');
if exist(clinical_case_file, 'file')
    fprintf('\n');
    fprintf('========================================================================\n');
    fprintf('STEP 3/3: CLINICAL CASE RECONSTRUCTION (Real Case - No Ground Truth)\n');
    fprintf('========================================================================\n');
    fprintf('Started at: %s\n', datestr(now));
    fprintf('Log file: output/results/clinical_log_%s.txt\n\n', timestamp);

    % Start diary for clinical reconstruction
    clinical_log = fullfile('output', 'results', sprintf('clinical_log_%s.txt', timestamp));
    diary(clinical_log);

    try
        % Run the clinical reconstruction
        fprintf('Running RECONSTRUCT_REAL_CLINICAL_CASE.m...\n');
        RECONSTRUCT_REAL_CLINICAL_CASE;
        fprintf('\n✓ Clinical reconstruction completed successfully!\n\n');
        clinical_success = true;
    catch ME
        fprintf('\n✗ ERROR in Clinical Reconstruction:\n');
        fprintf('   %s\n', ME.message);
        clinical_success = false;
    end

    % Stop diary for clinical reconstruction
    diary off;
else
    fprintf('\n');
    fprintf('========================================================================\n');
    fprintf('STEP 3/3: CLINICAL CASE RECONSTRUCTION\n');
    fprintf('========================================================================\n');
    fprintf('⚠ No clinical case file found (input_cases/real_clinical_case.stl)\n');
    fprintf('  Skipping clinical reconstruction.\n');
    fprintf('  To enable: Place real_clinical_case.stl in input_cases/ folder\n\n');
end

%% Summary
fprintf('\n');
fprintf('========================================================================\n');
fprintf('ANALYSIS COMPLETE\n');
fprintf('========================================================================\n');
fprintf('Finished at: %s\n\n', datestr(now));

fprintf('Results:\n');
if pipeline_success
    fprintf('  ✓ SSM Pipeline: SUCCESS\n');
    fprintf('    Log saved to: %s\n', pipeline_log);
else
    fprintf('  ✗ SSM Pipeline: FAILED\n');
    fprintf('    Check log: %s\n', pipeline_log);
end

if analysis_success
    fprintf('  ✓ Statistical Analysis: SUCCESS\n');
    fprintf('    Log saved to: %s\n', analysis_log);
elseif pipeline_success
    fprintf('  ✗ Statistical Analysis: FAILED\n');
    fprintf('    Check log: %s\n', analysis_log);
else
    fprintf('  - Statistical Analysis: SKIPPED\n');
end

if clinical_success
    fprintf('  ✓ Clinical Reconstruction: SUCCESS\n');
    fprintf('    Log saved to: %s\n', clinical_log);
elseif ~isempty(clinical_log)
    fprintf('  ✗ Clinical Reconstruction: FAILED\n');
    fprintf('    Check log: %s\n', clinical_log);
else
    fprintf('  - Clinical Reconstruction: SKIPPED (no input file)\n');
end

fprintf('\n');
fprintf('Output files location: ./output/results/\n');
fprintf('SSM model location: ./SSM/ssm_female_mandible.mat\n');
if clinical_success
    fprintf('Clinical case results: ./output/results/clinical_reconstruction/\n');
end
fprintf('\n');

if pipeline_success && analysis_success
    if clinical_success
        fprintf('🎉 Complete pipeline (SSM + Analysis + Clinical) finished successfully!\n');
    else
        fprintf('🎉 Analysis pipeline (SSM + Statistics) completed successfully!\n');
    end
else
    fprintf('⚠ Analysis completed with errors. Please check log files.\n');
end

fprintf('========================================================================\n\n');
