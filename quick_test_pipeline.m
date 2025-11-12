%% Quick Pipeline Test - Ridotto per testing rapido
% Tempo stimato: 40-50 minuti
% Scopo: Verificare che tutto funzioni correttamente

% Add paths (same as run_pipeline.m)
[script_dir, ~, ~] = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(script_dir, 'src')));
addpath(fullfile(script_dir, 'config'));

% Configurazione ottimizzata per test
config = pipeline_config();
config.registration.template_index = 10;           % Usa il template già identificato
config.registration.num_iterations = 2;            % Ridotto a 2 cicli completi
config.registration.rigid_icp.iterations = 50;     % Iterazioni per convergenza
config.registration.nonrigid_icp.iterations = 10;  % Ridotto a 10 iterazioni interne

fprintf('\n=== Quick Pipeline Test ===\n');
fprintf('Template index: %d\n', config.registration.template_index);
fprintf('Registration cycles: %d\n', config.registration.num_iterations);
fprintf('Rigid ICP max iterations: %d\n', config.registration.rigid_icp.iterations);
fprintf('Non-rigid ICP iterations: %d\n', config.registration.nonrigid_icp.iterations);
fprintf('Tempo stimato: 35-40 minuti\n\n');

% Esegui la pipeline (force per ignorare checkpoints)
try
    run_pipeline('config', config, 'force', true);
    fprintf('\n[OK] Pipeline completata con successo!\n');
catch ME
    fprintf('\n[ERROR] Errore durante l''esecuzione:\n');
    fprintf('  %s\n', ME.message);
    rethrow(ME);
end
