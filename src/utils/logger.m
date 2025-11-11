function logger(message, varargin)
% LOGGER Simple logging utility
%
% Syntax:
%   logger(message)
%   logger(message, 'level', 'INFO')
%   logger(message, 'level', 'DEBUG')
%
% Inputs:
%   message - String message to log
%   'level' - Log level: 'DEBUG', 'INFO', 'WARNING', 'ERROR'
%
% Example:
%   logger('Processing started', 'level', 'INFO');

    % Convert message to string if needed
    if isnumeric(message)
        message = num2str(message);
    elseif ~ischar(message) && ~isstring(message)
        message = char(message);
    end

    % Parse optional level argument
    level = 'INFO';  % Default
    if ~isempty(varargin)
        for i = 1:2:length(varargin)
            if i <= length(varargin) && ischar(varargin{i})
                if strcmpi(varargin{i}, 'level') && i+1 <= length(varargin)
                    level = varargin{i+1};
                    break;
                end
            end
        end
    end

    level = upper(level);

    % Format timestamp
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    % Level prefix
    switch level
        case 'DEBUG'
            prefix = '[DEBUG]';
        case 'INFO'
            prefix = '[INFO] ';
        case 'WARNING'
            prefix = '[WARN] ';
        case 'ERROR'
            prefix = '[ERROR]';
        otherwise
            prefix = '[INFO] ';
    end

    % Print formatted message
    fprintf('%s %s %s\n', timestamp, prefix, message);

end
