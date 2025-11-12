# Guida Pipeline SSM

## Script Disponibili

### 1. Test Rapido (`quick_test_pipeline.m`)
**Tempo**: ~30-35 minuti
**Scopo**: Verificare che tutto funzioni correttamente

```matlab
quick_test_pipeline
```

**Parametri**:
- Template index: 10 (pre-selezionato)
- Registration cycles: 2
- Local Optimization: **disabilitata** (per velocità)
- Rigid iterations: 50
- Non-rigid iterations: 10

**Quando usarlo**:
- ✅ Dopo aver risolto bug
- ✅ Per testare modifiche al codice
- ✅ Per verifiche rapide
- ✅ Durante lo sviluppo

**Nota**: La Local Optimization (aggiornamento iterativo del template) è disabilitata per ridurre il tempo di esecuzione.

### 2. Pipeline Completa (`full_pipeline.m`)
**Tempo**: ~4-6 ore
**Scopo**: Produrre risultati finali di qualità

```matlab
full_pipeline
```

**Parametri**:
- Template selection: Automatica
- Registration cycles: 3
- Local Optimization: **abilitata** (per massima qualità)
- Rigid iterations: 100
- Non-rigid iterations: 50

**Quando usarlo**:
- ✅ Per analisi finale
- ✅ Per risultati da pubblicare
- ✅ Quando la qualità è critica

**Nota**: La Local Optimization è abilitata per ottenere la migliore accuratezza possibile.

## Script di Test Unitari

### Test Template Selection (`test_template_selection.m`)
**Tempo**: ~5-10 minuti
Test veloce dell'algoritmo di selezione del template

```matlab
test_template_selection
```

### Test Configurazioni (`test_configurations.m`)
**Tempo**: ~1 minuto
Verifica che tutte le configurazioni siano valide

```matlab
test_configurations
```

## Workflow Consigliato

```mermaid
graph TD
    A[Modifiche al codice] --> B[test_configurations]
    B --> C{OK?}
    C -->|No| A
    C -->|Sì| D[test_template_selection]
    D --> E{OK?}
    E -->|No| A
    E -->|Sì| F[quick_test_pipeline]
    F --> G{OK?}
    G -->|No| A
    G -->|Sì| H[full_pipeline]
```

## Interruzione e Ripresa

Per interrompere: **Ctrl+C**

Per riprendere con parametri diversi:
```matlab
config = pipeline_config();
config.registration.template_index = 10;  % Usa template già calcolato
config.registration.rigid_iters = 2;
config.registration.nonrigid_iters = 10;
run_pipeline('config', config);
```

## Personalizzazione

Puoi modificare i parametri direttamente negli script o creare configurazioni custom:

```matlab
addpath('ssm-new-modules');
config = pipeline_config();

% Personalizza
config.registration.template_index = 5;
config.registration.num_iterations = 3;
config.registration.update_template_each_iteration = true;  % Local Optimization
config.registration.rigid_icp.iterations = 100;
config.registration.nonrigid_icp.iterations = 20;

run_pipeline('config', config);
```

### Local Optimization

La **Local Optimization** è l'aggiornamento iterativo del template durante la registrazione:

- **Abilitata** (default): Ad ogni iterazione, il template viene aggiornato selezionando lo specimen più vicino alla media corrente. Questo migliora l'accuratezza ma aumenta il tempo di calcolo.

- **Disabilitata** (quick test): Il template rimane fisso per tutte le iterazioni, riducendo significativamente il tempo di esecuzione (~25% più veloce).

```matlab
config.registration.update_template_each_iteration = true;   % Massima qualità
config.registration.update_template_each_iteration = false;  % Test rapidi
```
