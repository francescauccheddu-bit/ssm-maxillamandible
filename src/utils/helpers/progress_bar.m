function progress_bar(current, total, varargin)
% PROGRESS_BAR Display progress bar for iterations
%
% Usage:
%   progress_bar(current, total)
%   progress_bar(current, total, 'message', 'Processing')
%
% Parameters:
%   current - Current iteration number
%   total - Total number of iterations
%   'message' - Optional message to display (default: '')

    p = inputParser;
    addRequired(p, 'current', @isnumeric);
    addRequired(p, 'total', @isnumeric);
    addParameter(p, 'message', '', @ischar);
    parse(p, current, total, varargin{:});

    msg = p.Results.message;

    % Calculate progress
    percent = round((current / total) * 100);
    bar_length = 40;
    filled = round((percent / 100) * bar_length);

    % Build bar
    bar = ['[' repmat('=', 1, filled) repmat(' ', 1, bar_length - filled) ']'];

    % Display
    if ~isempty(msg)
        fprintf('\r%s: %s %3d%% (%d/%d)', msg, bar, percent, current, total);
    else
        fprintf('\r%s %3d%% (%d/%d)', bar, percent, current, total);
    end

    % Newline at end
    if current == total
        fprintf('\n');
    end

end
