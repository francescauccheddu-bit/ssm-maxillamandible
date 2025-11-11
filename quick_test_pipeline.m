%% Quick Pipeline Test - Ridotto per testing rapido
% Tempo stimato: 40-50 minuti
% Scopo: Verificare che tutto funzioni correttamente

addpath('ssm-new-modules');

% Configurazione ottimizzata per test
config = pipeline_config();
config.registration.template_index = 10;  % Usa il template già identificato
config.registration.rigid_iters = 2;      % Ridotto a 2 iterazioni
config.registration.nonrigid_iters = 10;  % Ridotto a 10 iterazioni

fprintf('\n=== Quick Pipeline Test ===\n');
fprintf('Template index: %d\n', config.registration.template_index);
fprintf('Rigid iterations: %d\n', config.registration.rigid_iters);
fprintf('Non-rigid iterations: %d\n', config.registration.nonrigid_iters);
fprintf('Tempo stimato: 40-50 minuti\n\n');

% Esegui la pipeline
try
    run_pipeline('config', config);
    fprintf('\n✓ Pipeline completata con successo!\n');
catch ME
    fprintf('\n✗ Errore durante l'esecuzione:\n');
    fprintf('  %s\n', ME.message);
    rethrow(ME);
end
