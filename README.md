# SSM Mandible Analysis - Complete Pipeline

Statistical Shape Model (SSM) analysis for mandibular morphology with sex difference testing.

---

## 🚀 Quick Start

### Run Complete Analysis

```matlab
RUN_FULL_ANALYSIS
```

This script automatically:
1. Builds the SSM from input STL files (`PIPELINE_SSM_MODULAR_V2`)
2. Performs statistical sex difference analysis (`MANUSCRIPT_SSM_MANDIBLE_ANALYSIS`)
3. **(Optional)** Reconstructs real clinical case if `input_cases/real_clinical_case.stl` exists
4. Saves all console output to log files (prevents data loss if `clc` is used)
5. Generates results and figures

**Expected runtime**: 30-90 minutes (+ 5-10 min if clinical reconstruction)

**Output logs**:
- `output/results/pipeline_log_[timestamp].txt` - Complete SSM building process
- `output/results/analysis_log_[timestamp].txt` - Statistical analysis results
- `output/results/clinical_log_[timestamp].txt` - Clinical reconstruction (if enabled)

---

## 🏥 Clinical Case Reconstruction

Two workflows available for clinical applications:

### Option 1: Validation (with ground truth)

For testing/validation when you have BOTH damaged and complete models:

1. **Place files** in `input_cases/`:
   - `mandible_damaged.stl` - Damaged mandible
   - `mandible_complete.stl` - Complete mandible (ground truth)

2. **Run**:
   ```matlab
   MANUSCRIPT_SSM_MANDIBLE_ANALYSIS
   ```
   Auto-detects files and computes accuracy metrics (RMSE).

3. **Results**: `output/clinical_case_results/`

### Option 2: Real Clinical Case (no ground truth)

For actual patient data where only the damaged model exists:

1. **Place file** in `input_cases/`:
   - `real_clinical_case.stl` - Patient's damaged mandible

2. **Run**:
   ```matlab
   RUN_FULL_ANALYSIS  % ← Automatically includes clinical reconstruction!
   ```

   The script auto-detects `real_clinical_case.stl` and runs reconstruction as STEP 3.

3. **Results**: `output/results/clinical_reconstruction/`
   - Reconstructed anatomy for surgical planning
   - Qualitative analysis (no RMSE, no ground truth needed)
   - Visual comparisons with population mean

**Alternative** (run clinical reconstruction only):
```matlab
RECONSTRUCT_REAL_CLINICAL_CASE  % Manual execution (requires SSM already built)
```

### Clinical Applications

- Traumatic injury reconstruction
- Pre-operative planning for tumor resection
- Congenital defect reconstruction
- Asymmetry correction

See `input_cases/README.md` for detailed instructions.

---

## Manual Step-by-Step (Advanced Users)

### Step 1: Build SSM
```matlab
PIPELINE_SSM_MODULAR_V2
```
- **Input**: STL files in `Segmentazioni_Female/`
- **Output**: `SSM/ssm_female_mandible.mat`
- **Duration**: ~30-60 minutes

### Step 2: Statistical Analysis
```matlab
MANUSCRIPT_SSM_MANDIBLE_ANALYSIS
```
- **Input**: SSM model from Step 1
- **Output**: Results files and figures in `output/results/`
- **Duration**: ~5-15 minutes

---

## 📁 Directory Structure

```
.
├── README.md                           # This file
├── USAGE_INSTRUCTIONS.md               # Detailed technical documentation
│
├── RUN_FULL_ANALYSIS.m                 # ⭐ Main script (pipeline + analysis)
├── PIPELINE_SSM_MODULAR_V2.m          # SSM construction pipeline
├── MANUSCRIPT_SSM_MANDIBLE_ANALYSIS.m # Statistical analysis (+ optional clinical cases)
├── RECONSTRUCT_REAL_CLINICAL_CASE.m   # Real clinical case reconstruction
│
├── Segmentazioni_Female/               # Input STL files (training data)
├── input_cases/                        # Clinical case STL files (optional)
│   ├── mandible_damaged.stl           # For validation (with ground truth)
│   ├── mandible_complete.stl          # Ground truth (optional)
│   └── real_clinical_case.stl         # Real patient case (no ground truth)
│
├── SSM/                                # SSM model output
├── output/                             # Analysis & reconstruction results
│   ├── checkpoints/                   # Pipeline checkpoints
│   ├── RESULTS/                       # Statistical analysis results
│   ├── clinical_case_results/         # Validation case (with ground truth)
│   └── real_clinical_case/            # Real case reconstruction
│
├── paper/                              # Reference papers
└── unused/                             # Archived scripts
```

---

## 📊 Output Files

After running `RUN_FULL_ANALYSIS`, you will find:

```
SSM/
└── ssm_female_mandible.mat             # Statistical Shape Model

output/
├── pipeline_log_[timestamp].txt        # Complete pipeline console output
├── analysis_log_[timestamp].txt        # Statistical analysis output
├── checkpoints/                        # Pipeline intermediate files
└── results/
    ├── PC_sex_differences.txt          # Statistical test results
    ├── PC*_visualization.fig           # MATLAB figures
    └── ...                             # Additional results
```

---

## ⚙️ Pipeline Phases

The `PIPELINE_SSM_MODULAR_V2` consists of 4 automated phases:

1. **Preprocessing** (~10-20 min): Load, center, remesh STL files
2. **Registration** (~20-40 min): ICP + GPA alignment for correspondence
3. **SSM Building** (~5-10 min): Principal Component Analysis (PCA)
4. **Organization** (~1-2 min): Export and summarize results

**Progress tracking**: Watch console output or check log files

---

## 🔬 Statistical Analysis

`MANUSCRIPT_SSM_MANDIBLE_ANALYSIS` performs:

- Sex difference testing for each PC (t-tests with Bonferroni correction)
- Effect size calculation (Cohen's d)
- Visualization of significant PCs
- Export of shape modes at ±3 standard deviations

**Key output**: Identifies which PCs show significant sex differences

---

## ⚠️ Important Notes

### Before Running

- **Input filtering**: Remove excluded/artifact STL files from `Segmentazioni_Female/`
- **No automatic exclusion**: Pipeline assumes all input files are valid
- **Sufficient disk space**: ~1-2 GB for outputs

### During Execution

- **Do NOT close MATLAB** during pipeline execution
- **Console output is saved**: Even if you run `clc`, logs are preserved
- **Long runtime normal**: Registration phase can take 20-40 minutes

### After Completion

- Check log files for errors or warnings
- Verify `SSM/ssm_female_mandible.mat` was created
- Review results in `output/results/`

---

## 💻 Requirements

- **MATLAB**: R2018b or newer
- **Toolboxes**: Statistics and Machine Learning Toolbox
- **RAM**: ≥8 GB recommended
- **Storage**: ~2 GB for outputs
- **Input data**: STL files of mandible segmentations

---

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Checkpoint not found" | Run `PIPELINE_SSM_MODULAR_V2` first |
| "Out of memory" | Reduce number of samples or increase MATLAB heap |
| "No sex differences found" | Check sample size and input data quality |
| Process interrupted | Re-run `RUN_FULL_ANALYSIS` (uses checkpoints) |

**For detailed technical info**: See `USAGE_INSTRUCTIONS.md`

---

## 📚 Reference

**Methodology based on**:
- van Veldhuizen et al. (2023) "Development of a Statistical Shape Model..." *J. Clin. Med.* 12:3767

**Papers available in**: `paper/` directory

---

**Last updated**: November 8, 2025
**Pipeline version**: Modular V2
**Branch**: `claude/ssm-modular-pipeline-final`
