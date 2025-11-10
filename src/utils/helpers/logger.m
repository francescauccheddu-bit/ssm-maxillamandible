function logger(message, varargin)
% LOGGER Centralized logging function
%
% Usage:
%   logger(message)
%   logger(message, 'level', 'INFO')
%   logger(message, 'level', 'WARNING', 'timestamp', true)
%
% Parameters:
%   message - String message to log
%   'level' - Log level: 'INFO', 'WARNING', 'ERROR', 'DEBUG' (default: 'INFO')
%   'timestamp' - Boolean, add timestamp (default: true)
%   'newline' - Boolean, add newline after message (default: true)

    p = inputParser;
    addRequired(p, 'message', @ischar);
    addParameter(p, 'level', 'INFO', @ischar);
    addParameter(p, 'timestamp', true, @islogical);
    addParameter(p, 'newline', true, @islogical);
    parse(p, message, varargin{:});

    level = upper(p.Results.level);
    add_timestamp = p.Results.timestamp;
    add_newline = p.Results.newline;

    % Format message
    formatted_msg = '';

    % Add timestamp
    if add_timestamp
        formatted_msg = sprintf('[%s] ', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    end

    % Add level
    switch level
        case 'INFO'
            level_str = '[INFO]   ';
        case 'WARNING'
            level_str = '[WARNING]';
        case 'ERROR'
            level_str = '[ERROR]  ';
        case 'DEBUG'
            level_str = '[DEBUG]  ';
        otherwise
            level_str = '[INFO]   ';
    end
    formatted_msg = [formatted_msg level_str ' '];

    % Add message
    formatted_msg = [formatted_msg message];

    % Add newline
    if add_newline
        formatted_msg = [formatted_msg '\n'];
    end

    % Print
    fprintf(formatted_msg);

end
