function [meshes, metadata] = load_training_data(config)
% LOAD_TRAINING_DATA Load STL files from female/male directories
%
% Usage:
%   [meshes, metadata] = load_training_data(config)
%
% Parameters:
%   config - Configuration struct from pipeline_config()
%
% Returns:
%   meshes - Cell array of structs with fields:
%           .vertices - Nx3 vertex coordinates
%           .faces - Mx3 face indices
%   metadata - Struct with fields:
%           .sex - Cell array of 'F' or 'M'
%           .ids - Cell array of specimen IDs
%           .filenames - Cell array of original filenames

    logger('Loading training data...', 'level', 'INFO');

    % Get female files
    female_path = config.paths.input.female;
    female_files = dir(fullfile(female_path, '*.stl'));
    logger(sprintf('Found %d female specimens in %s', length(female_files), female_path));

    % Get male files
    male_path = config.paths.input.male;
    male_files = dir(fullfile(male_path, '*.stl'));
    logger(sprintf('Found %d male specimens in %s', length(male_files), male_path));

    % Total number of meshes
    num_female = length(female_files);
    num_male = length(male_files);
    num_total = num_female + num_male;

    if num_total == 0
        error('load_training_data:NoFiles', 'No STL files found in input directories');
    end

    % Preallocate
    meshes = cell(num_total, 1);
    metadata.sex = cell(num_total, 1);
    metadata.ids = cell(num_total, 1);
    metadata.filenames = cell(num_total, 1);

    % Load female specimens
    logger('Loading female specimens...');
    for i = 1:num_female
        progress_bar(i, num_female, 'message', 'Female specimens');

        filepath = fullfile(female_path, female_files(i).name);
        [V, F] = read_stl(filepath);

        meshes{i}.vertices = V;
        meshes{i}.faces = F;
        metadata.sex{i} = 'F';
        metadata.ids{i} = sprintf('F%03d', i);
        metadata.filenames{i} = female_files(i).name;
    end

    % Load male specimens
    logger('Loading male specimens...');
    for i = 1:num_male
        progress_bar(i, num_male, 'message', 'Male specimens');

        idx = num_female + i;
        filepath = fullfile(male_path, male_files(i).name);
        [V, F] = read_stl(filepath);

        meshes{idx}.vertices = V;
        meshes{idx}.faces = F;
        metadata.sex{idx} = 'M';
        metadata.ids{idx} = sprintf('M%03d', i);
        metadata.filenames{idx} = male_files(i).name;
    end

    logger(sprintf('Successfully loaded %d meshes (%d female, %d male)', ...
        num_total, num_female, num_male), 'level', 'INFO');

end
