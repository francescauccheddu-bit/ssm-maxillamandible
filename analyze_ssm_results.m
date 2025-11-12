% ANALYZE_SSM_RESULTS Wrapper script to analyze SSM results
%
% This is a convenience wrapper that adds the scripts directory to the path
% and runs the main analysis script.
%
% The script executes:
% 1. Visualization of variance distribution across PCs
% 2. Generation of STL files for PC1, PC2, PC3 at ±3SD
%
% Usage:
%   >> analyze_ssm_results
%
% To modify parameters, edit scripts/analyze_ssm_results.m
%
% Output:
%   - output/variance_analysis/  : Variance plots and statistics
%   - output/pc_morphology/      : STL files of morphological variations

% Add scripts directory to path
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'scripts'));

% Save current directory and change to project root
original_dir = pwd;
cd(script_dir);

try
    % Run the actual analysis script
    run(fullfile(script_dir, 'scripts', 'analyze_ssm_results.m'));
catch ME
    % Restore directory even if error occurs
    cd(original_dir);
    rethrow(ME);
end

% Restore original directory
cd(original_dir);
