function progress_bar(current, total, varargin)
% PROGRESS_BAR Display progress bar
%
% Syntax:
%   progress_bar(current, total)
%   progress_bar(current, total, 'message', 'Processing')
%
% Inputs:
%   current - Current iteration number
%   total - Total number of iterations
%   'message' - Optional message to display
%
% Example:
%   for i = 1:100
%       progress_bar(i, 100, 'message', 'Loading');
%   end

    % Parse inputs
    p = inputParser;
    addRequired(p, 'current', @isnumeric);
    addRequired(p, 'total', @isnumeric);
    addParameter(p, 'message', 'Progress', @ischar);
    parse(p, current, total, varargin{:});

    message = p.Results.message;
    percent = round(100 * current / total);

    % Display progress
    if current == 1
        fprintf('%s: %3d%% [', message, percent);
    end

    % Update progress bar every 10%
    if mod(percent, 10) == 0 && mod(current-1, max(1, round(total/10))) == 0
        fprintf('=');
    end

    if current == total
        fprintf('] Complete\n');
    end

end
