function resume_pipeline(varargin)
% RESUME_PIPELINE Resume pipeline from last successful checkpoint
%
% Automatically detects last completed phase and resumes from there.
% No need to specify which phase - it figures it out!
%
% Usage:
%   resume_pipeline()              % Resume from last checkpoint
%   resume_pipeline('from', 2)     % Force resume from phase 2
%   resume_pipeline('force')       % Recompute all (ignore checkpoints)
%
% Examples:
%   % Pipeline crashed during phase 2? Just run:
%   resume_pipeline()
%
%   % Want to re-run phase 3 onwards with same preprocessing/registration:
%   resume_pipeline('from', 3)
%
% See also: run_pipeline

    %% Parse input
    p = inputParser;
    addParameter(p, 'from', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'force', false, @islogical);
    parse(p, varargin{:});

    force_phase = p.Results.from;
    force_recompute = p.Results.force;

    %% Setup
    [script_dir, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(script_dir, 'src')));
    addpath(fullfile(script_dir, 'config'));

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  Resume Pipeline from Checkpoint\n');
    fprintf('========================================\n\n');

    % Load config
    config = pipeline_config();

    if ~config.checkpoint.enabled
        warning('Checkpoints are disabled in config! Enabling them now...');
        config.checkpoint.enabled = true;
    end

    % Phase names
    phase_names = {
        'Preprocessing';
        'Registration';
        'SSM Building';
        'Statistical Analysis';
        'Clinical Reconstruction';
    };

    %% Find last completed phase
    if isempty(force_phase)
        fprintf('Searching for checkpoints in: %s\n', config.checkpoint.dir);

        last_completed = 0;
        for i = 1:length(phase_names)
            checkpoint_file = get_checkpoint_file(config, i);
            if exist(checkpoint_file, 'file')
                fprintf('  [✓] Phase %d: %s (checkpoint found)\n', i, phase_names{i});
                last_completed = i;
            else
                fprintf('  [ ] Phase %d: %s (not completed)\n', i, phase_names{i});
            end
        end

        if last_completed == 0
            fprintf('\nNo checkpoints found. Running full pipeline...\n');
            start_phase = 1;
        elseif last_completed == length(phase_names)
            fprintf('\nAll phases completed! To regenerate results:\n');
            fprintf('  - To recompute everything: run_pipeline(''force'', true)\n');
            fprintf('  - To use saved SSM model:  use_ssm()\n');
            return;
        else
            start_phase = last_completed + 1;
            fprintf('\nResuming from Phase %d: %s\n', start_phase, phase_names{start_phase});
        end
    else
        start_phase = force_phase;
        fprintf('Forcing resume from Phase %d: %s\n', start_phase, phase_names{start_phase});
    end

    fprintf('\n');

    %% Resume pipeline
    if force_recompute
        run_pipeline('force', true, 'start_from', start_phase);
    else
        run_pipeline('start_from', start_phase);
    end

end

function filename = get_checkpoint_file(config, phase_idx)
    % Get checkpoint filename for a phase
    filename = fullfile(config.checkpoint.dir, ...
        sprintf('checkpoint_phase%d.mat', phase_idx));
end
