%% Full Pipeline - Parametri completi per risultati finali
% Tempo stimato: 4-6 ore
% Scopo: Produrre risultati di qualità per analisi finale

% Add paths (same as run_pipeline.m)
[script_dir, ~, ~] = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(script_dir, 'src')));
addpath(fullfile(script_dir, 'config'));

% Configurazione completa
config = pipeline_config();
% Template selection automatica
config.registration.rigid_icp.iterations = 5;      % Iterazioni complete
config.registration.nonrigid_icp.iterations = 50;  % Iterazioni complete

fprintf('\n=== Full Pipeline ===\n');
fprintf('Template selection: Automatica\n');
fprintf('Registration cycles: %d\n', config.registration.num_iterations);
fprintf('Local Optimization: enabled (for best quality)\n');
fprintf('Rigid iterations: %d\n', config.registration.rigid_icp.iterations);
fprintf('Non-rigid iterations: %d\n', config.registration.nonrigid_icp.iterations);
fprintf('Tempo stimato: 4-6 ore\n\n');

% Esegui la pipeline
try
    run_pipeline('config', config);
    fprintf('\n[OK] Pipeline completata con successo!\n');
catch ME
    fprintf('\n[ERROR] Errore durante l''esecuzione:\n');
    fprintf('  %s\n', ME.message);
    rethrow(ME);
end
