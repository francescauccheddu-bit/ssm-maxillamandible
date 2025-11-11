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

    % Separate format arguments from 'level' parameter
    level = 'INFO';  % Default
    format_args = {};

    i = 1;
    while i <= length(varargin)
        if ischar(varargin{i}) && strcmpi(varargin{i}, 'level') && i+1 <= length(varargin)
            level = varargin{i+1};
            i = i + 2;
        else
            % It's a format argument
            format_args{end+1} = varargin{i};
            i = i + 1;
        end
    end

    % Apply sprintf formatting if format arguments exist
    if ~isempty(format_args)
        try
            message = sprintf(message, format_args{:});
        catch
            % If sprintf fails, just use the message as-is
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
