%% Full Pipeline - Parametri completi per risultati finali
% Tempo stimato: 4-6 ore
% Scopo: Produrre risultati di qualità per analisi finale

addpath('ssm-new-modules');

% Configurazione completa
config = pipeline_config();
% Template selection automatica
config.registration.rigid_icp.iterations = 5;      % Iterazioni complete
config.registration.nonrigid_icp.iterations = 50;  % Iterazioni complete

fprintf('\n=== Full Pipeline ===\n');
fprintf('Template selection: Automatica\n');
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
