# Statistical Shape Model (SSM) for Maxilla/Mandible

**Modular MATLAB pipeline for creating Statistical Shape Models from STL mesh data of mandibles and maxillae.**

---

## 🔍 Overview

This pipeline implements a complete workflow for building **Statistical Shape Models (SSM)** of mandibular and maxillary anatomy using Principal Component Analysis (PCA) on registered 3D meshes.

## ✨ Features

- **Modular Architecture**: Clean, maintainable, extensible code
- **Complete Pipeline**: Preprocessing → Registration → SSM Building → Analysis → Reconstruction
- **Robust Execution**: Checkpoint system, error handling, detailed logging
- **Statistical Analysis**: Sex-based morphological testing with t-tests and effect sizes
- **Clinical Tools**: Damaged mandible reconstruction with anatomical constraints

---

## 🚀 Quick Start

```matlab
% 1. Place STL files in:
%    - data/input/female/
%    - data/input/male/

% 2. Run pipeline
run_pipeline
```

---

## 📦 Requirements

- MATLAB R2018b+
- Statistics and Machine Learning Toolbox
- 8GB+ RAM
- ~2GB storage

---

## 💻 Installation

```bash
git clone https://github.com/francescauccheddu-bit/ssm-maxillamandible.git
cd ssm-maxillamandible
```

In MATLAB:
```matlab
addpath(genpath('src'));
addpath('config');
run_pipeline
```

---

## 📁 Directory Structure

```
ssm-maxillamandible/
├── run_pipeline.m         # Main entry point
├── config/                # Configuration
├── src/                   # Source code modules
│   ├── core/             # SSM building (PCA)
│   ├── preprocessing/    # Data loading, remeshing
│   ├── registration/     # ICP, Procrustes
│   ├── analysis/         # Statistical testing
│   ├── clinical/         # Reconstruction
│   └── utils/            # I/O, visualization, helpers
├── data/
│   ├── input/            # STL files (female, male, clinical_cases)
│   └── output/           # Results, models, reconstructions
├── tests/                # Test scripts
└── docs/                 # Documentation
```

---

## 🔄 Pipeline Stages

1. **Preprocessing**: Load STL, remesh (1.0mm edge), normalize
2. **Registration**: Rigid + non-rigid ICP, Procrustes alignment
3. **SSM Building**: PCA on aligned meshes
4. **Analysis**: Statistical sex difference testing (optional)
5. **Reconstruction**: Clinical case reconstruction (optional)

---

## ⚙️ Configuration

Edit `config/pipeline_config.m`:

```matlab
config.preprocessing.edge_length = 1.0;           % Remesh resolution
config.registration.nonrigid_icp.iterations = 15;
config.ssm.max_components = 15;                   % Max PCs
config.analysis.significance_level = 0.05;
config.clinical.num_pcs = 5;                      % PCs for reconstruction
```

---

## 📊 Output

- **SSM Model**: `data/output/models/ssm_model.mat`
- **Statistics**: `data/output/results/*.csv`, figures
- **Reconstructions**: `data/output/reconstructions/*.stl`

---

## 🔬 Post-Pipeline Analysis

After running the pipeline, analyze your SSM results:

```matlab
% Complete analysis (variance distribution + PC morphology STLs)
analyze_ssm_results

% This generates:
% - output/variance_analysis/       : Variance plots and statistics
% - output/pc_morphology/            : STL files for PC1-3 at ±3SD
```

See `scripts/README_SSM_ANALYSIS.md` for advanced analysis options.

---

## 📖 Usage Examples

```matlab
% Run complete pipeline
run_pipeline

% Resume from phase 3
run_pipeline('start_from', 3)

% Run only registration
run_pipeline('only', 2)

% Force recomputation
run_pipeline('force', true)

% Custom configuration
cfg = pipeline_config();
cfg.preprocessing.edge_length = 1.5;
run_pipeline('config', cfg)
```

---

## 📄 Citation

Based on methodology from:
- van Veldhuizen et al. (2023), "Development of a Statistical Shape Model...", *Journal of Clinical Medicine*, 12:3767

---

## 📜 License

MIT License - see [LICENSE](LICENSE) file

---

**Version**: 2.0.0 (Modular Rewrite)
**Last Updated**: November 2024
