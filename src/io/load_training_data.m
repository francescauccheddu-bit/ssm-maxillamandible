function [meshes, metadata] = load_training_data(config)
% LOAD_TRAINING_DATA Load training meshes from STL files
%
% Syntax:
%   [meshes, metadata] = load_training_data(config)
%
% Inputs:
%   config - Configuration struct with paths
%
% Outputs:
%   meshes - Cell array of mesh structs with .vertices and .faces
%   metadata - Struct with .sex, .specimen_ids, .filenames
%
% Example:
%   [meshes, metadata] = load_training_data(config);

    meshes = {};
    metadata.sex = {};
    metadata.specimen_ids = {};
    metadata.filenames = {};

    % Load female meshes
    if ~isempty(config.paths.training_female)
        female_files = dir(fullfile(config.paths.training_female, '*.stl'));
        logger(sprintf('Found %d female STL files', length(female_files)), 'level', 'INFO');

        for i = 1:length(female_files)
            filepath = fullfile(config.paths.training_female, female_files(i).name);
            logger(sprintf('Loading %s...', female_files(i).name), 'level', 'DEBUG');

            mesh = read_stl(filepath);
            meshes{end+1} = mesh;
            metadata.sex{end+1} = 'F';
            metadata.filenames{end+1} = female_files(i).name;

            % Extract specimen ID from filename (e.g., Mandible_12345.stl -> 12345)
            [~, name, ~] = fileparts(female_files(i).name);
            tokens = regexp(name, '(\d+)', 'tokens');
            if ~isempty(tokens)
                metadata.specimen_ids{end+1} = tokens{1}{1};
            else
                metadata.specimen_ids{end+1} = name;
            end
        end
    end

    % Load male meshes
    if ~isempty(config.paths.training_male) && exist(config.paths.training_male, 'dir')
        male_files = dir(fullfile(config.paths.training_male, '*.stl'));
        logger(sprintf('Found %d male STL files', length(male_files)), 'level', 'INFO');

        for i = 1:length(male_files)
            filepath = fullfile(config.paths.training_male, male_files(i).name);
            logger(sprintf('Loading %s...', male_files(i).name), 'level', 'DEBUG');

            mesh = read_stl(filepath);
            meshes{end+1} = mesh;
            metadata.sex{end+1} = 'M';
            metadata.filenames{end+1} = male_files(i).name;

            % Extract specimen ID from filename
            [~, name, ~] = fileparts(male_files(i).name);
            tokens = regexp(name, '(\d+)', 'tokens');
            if ~isempty(tokens)
                metadata.specimen_ids{end+1} = tokens{1}{1};
            else
                metadata.specimen_ids{end+1} = name;
            end
        end
    end

    if isempty(meshes)
        error('load_training_data:NoFiles', 'No STL files found in training directories');
    end

    logger(sprintf('Loaded %d total meshes', length(meshes)), 'level', 'INFO');

end
