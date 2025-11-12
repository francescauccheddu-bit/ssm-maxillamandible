# SSM Results Analysis Scripts

Scripts per analizzare i risultati del modello SSM (Statistical Shape Model).

## Scripts Disponibili

### 1. `analyze_ssm_results.m` (RACCOMANDATA)
**Script principale** che esegue l'analisi completa in un unico comando.

```matlab
% Esegue tutto in automatico
analyze_ssm_results
```

Questo script:
- Visualizza la distribuzione della varianza tra i componenti principali
- Genera file STL per PC1, PC2, PC3 a ±3SD
- Crea grafici e report automatici

### 2. `visualize_variance_distribution.m`
Analizza la distribuzione della varianza tra i componenti principali.

```matlab
% Con parametri default
visualize_variance_distribution('output/ssm_model.mat')

% Solo visualizzare
visualize_variance_distribution()
```

**Output:**
- `output/variance_analysis/variance_distribution.png` - Grafici
- `output/variance_analysis/variance_distribution.fig` - Figure MATLAB
- `output/variance_analysis/variance_summary.txt` - Statistiche testuali

**Grafici generati:**
1. Varianza spiegata per ogni PC (bar plot)
2. Varianza cumulativa (linea)
3. Scree plot (eigenvalues in scala log)
4. Dettaglio primi 10 PC

### 3. `generate_pc_morphology_stls.m`
Genera file STL per visualizzare l'impatto morfologico dei PC.

```matlab
% Con parametri default (PC1-3, ±3SD)
generate_pc_morphology_stls('output/ssm_model.mat', 'output/pc_morphology', [1,2,3], 3)

% Solo PC1 a ±2SD
generate_pc_morphology_stls('output/ssm_model.mat', 'output/pc_morphology', 1, 2)

% Primi 5 PC a ±3SD
generate_pc_morphology_stls('output/ssm_model.mat', 'output/pc_morphology', [1:5], 3)
```

**Parametri:**
- `ssm_model_path`: Percorso al file SSM (default: `'output/ssm_model.mat'`)
- `output_dir`: Directory output (default: `'output/pc_morphology'`)
- `pcs_to_generate`: Array dei PC da generare (default: `[1,2,3]`)
- `std_multiplier`: Moltiplicatore SD (default: `3`)

**Output:**
- `mean_shape.stl` - Forma media del modello
- `PC1_plus_3sd.stl` - PC1 a +3 deviazioni standard
- `PC1_minus_3sd.stl` - PC1 a -3 deviazioni standard
- `PC2_plus_3sd.stl`, `PC2_minus_3sd.stl` - PC2 variazioni
- `PC3_plus_3sd.stl`, `PC3_minus_3sd.stl` - PC3 variazioni
- `generation_summary.txt` - Riepilogo generazione

## Workflow Consigliato

### Dopo aver completato la pipeline:

```matlab
% 1. Esegui l'analisi completa
analyze_ssm_results

% 2. Apri i risultati
open output/variance_analysis/variance_distribution.png

% 3. Visualizza gli STL in un viewer esterno (MeshLab, 3D Slicer, etc.)
```

### Analisi personalizzata:

```matlab
% Visualizza solo la distribuzione della varianza
visualize_variance_distribution()

% Genera STL solo per PC1 e PC2 a ±2SD
generate_pc_morphology_stls('output/ssm_model.mat', 'output/pc_morphology', [1,2], 2)
```

## Interpretazione dei Risultati

### Distribuzione della Varianza
- **PC1** tipicamente cattura la variazione principale (es. dimensione generale)
- **PC2-3** catturano variazioni secondarie (es. forma, asimmetria)
- **Varianza cumulativa** indica quanti PC servono per rappresentare una certa percentuale della variazione totale

### File STL
- **mean_shape.stl**: Forma media di riferimento
- **PC#_plus_3sd.stl**: Mostra la morfologia estrema in una direzione
- **PC#_minus_3sd.stl**: Mostra la morfologia estrema nella direzione opposta

**Per visualizzare:**
1. Carica `mean_shape.stl` come riferimento
2. Carica `PC1_plus_3sd.stl` e confronta con la media
3. Carica `PC1_minus_3sd.stl` per vedere la variazione opposta
4. Ripeti per PC2 e PC3

**Software consigliati:**
- **MeshLab** (gratuito): https://www.meshlab.net/
- **3D Slicer** (gratuito, medical imaging): https://www.slicer.org/
- **CloudCompare** (gratuito): https://www.danielgm.net/cc/

## Troubleshooting

### Error: "SSM model file not found"
Soluzione: Esegui prima la pipeline completa
```matlab
run_pipeline
```

### Error: "PC# exceeds available components"
Soluzione: Verifica quanti componenti ha il tuo modello e riduci il parametro `pcs_to_generate`
```matlab
load('output/ssm_model.mat', 'ssm_model');
fprintf('Available components: %d\n', ssm_model.num_components);
```

### File STL non si aprono correttamente
Soluzione: Gli STL sono in formato ASCII. Se il tuo viewer richiede formato binario, usa uno strumento di conversione o modifica la funzione `write_stl_mesh`.

## Requisiti
- MATLAB R2018b o superiore
- SSM model già generato dalla pipeline
- Nessun toolbox aggiuntivo richiesto

## Output Directory Structure
```
output/
├── ssm_model.mat                          # Input (generato dalla pipeline)
├── variance_analysis/                     # Output analisi varianza
│   ├── variance_distribution.png
│   ├── variance_distribution.fig
│   └── variance_summary.txt
└── pc_morphology/                         # Output STL morfologie
    ├── mean_shape.stl
    ├── PC1_plus_3sd.stl
    ├── PC1_minus_3sd.stl
    ├── PC2_plus_3sd.stl
    ├── PC2_minus_3sd.stl
    ├── PC3_plus_3sd.stl
    ├── PC3_minus_3sd.stl
    └── generation_summary.txt
```

## Note
- I file STL possono essere di grandi dimensioni (diversi MB ciascuno)
- La generazione STL è veloce (~1-2 secondi per PC)
- I grafici vengono salvati sia in PNG (per visualizzazione) che in FIG (per editing MATLAB)
