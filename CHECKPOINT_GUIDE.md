# Checkpoint & Resume Guide

This guide explains how to efficiently use checkpoints to avoid recomputing expensive operations.

## 🎯 Key Concepts

**Checkpoints** = Saved results after each pipeline phase
- **Phase 1**: Preprocessing (remeshing, cleaning)
- **Phase 2**: Registration (ICP alignment)
- **Phase 3**: SSM Building (PCA computation)
- **Phase 4**: Statistical Analysis
- **Phase 5**: Clinical Reconstruction

## 📁 Where Checkpoints Are Saved

```
cache/checkpoints/
├── checkpoint_phase1.mat  (preprocessing results)
├── checkpoint_phase2.mat  (registration results)
├── checkpoint_phase3.mat  (SSM model)
└── ...
```

## 🚀 Typical Workflows

### First Time: Full Pipeline
```matlab
% Run complete pipeline (saves checkpoints automatically)
run_pipeline()

% Expected time with edge_length=2.5mm and 20 specimens:
%   Phase 1 (Preprocessing):  ~5 min
%   Phase 2 (Registration):   ~75 min  <- EXPENSIVE!
%   Phase 3 (SSM Building):   ~2 min
%   TOTAL: ~82 min
```

### Pipeline Crashed? Resume Automatically
```matlab
% Automatically detects last completed phase and continues
resume_pipeline()

% Example: If crashed during Phase 2, it will:
%   1. Load Phase 1 checkpoint (skip preprocessing)
%   2. Re-run Phase 2 from where it failed
%   3. Continue with Phase 3, 4, 5...
```

### Tweak Parameters Without Recomputing Everything
```matlab
% Already have preprocessing + registration done?
% Just rebuild SSM with different PCA settings:

run_pipeline('start_from', 3)

% This will:
%   - Load Phase 2 checkpoint (aligned meshes)
%   - Re-run Phase 3 onwards
%   - Saves HOURS of recomputation!
```

### Change Visualization Settings
```matlab
% SSM already built? Generate new visualizations:

use_ssm('num_modes', 5, 'std_range', [-2, -1, 0, 1, 2])

% This loads the saved SSM and exports:
%   - Mean shape STL
%   - 5 PCA modes × 5 variations = 25 STL files
%   - Statistics report
% Time: ~5 seconds!
```

### Force Recompute Everything
```matlab
% Changed edge_length or other preprocessing params?
% Need to recompute from scratch:

run_pipeline('force', true)

% This ignores all checkpoints and starts fresh
```

## 📊 Use Saved SSM for Results

After pipeline completes once, generate results without recomputation:

```matlab
% Generate all visualizations from saved model
use_ssm()

% Export more modes
use_ssm('num_modes', 10)

% Custom std deviations
use_ssm('std_range', [-4, -3, -2, -1, 0, 1, 2, 3, 4])

% Use different SSM file
use_ssm('model', 'path/to/my_ssm.mat')
```

### Output (in `output/ssm_results/`)
```
output/ssm_results/
├── mean_shape.stl
├── mode1_std-3.stl
├── mode1_std-2.stl
├── mode1_std-1.stl
├── mode1_std+0.stl
├── mode1_std+1.stl
├── mode1_std+2.stl
├── mode1_std+3.stl
├── mode2_std-3.stl
├── ...
└── ssm_statistics.txt
```

## ⚙️ Configuration

Enable/disable checkpointing in `config/pipeline_config.m`:

```matlab
config.checkpoint.enabled = true;  % Set to false to disable
config.checkpoint.dir = 'cache/checkpoints';
```

## 💾 Managing Checkpoints

### Clear Checkpoints (Start Fresh)
```bash
# From terminal
rm -rf cache/checkpoints/*

# Or from MATLAB
rmdir('cache/checkpoints', 's')
mkdir('cache/checkpoints')
```

### Check What's Saved
```matlab
ls cache/checkpoints/
```

### Checkpoint File Size
- Phase 1: ~50-200 MB (depends on mesh size)
- Phase 2: ~50-200 MB (aligned meshes)
- Phase 3: ~10-50 MB (SSM model)

## 🎓 Best Practices

1. **During Development**:
   - Keep checkpoints enabled
   - Test with small subset first
   - Use `resume_pipeline()` when things break

2. **Testing Parameters**:
   - Test `edge_length` values → need full recompute
   - Test registration params → start from Phase 1 checkpoint
   - Test PCA settings → start from Phase 2 checkpoint

3. **For Publication**:
   - Do final run with `force=true` to ensure clean computation
   - Save final SSM to dated file: `output/ssm_model_20250111.mat`
   - Use `use_ssm()` to generate all figures

4. **Disk Space**:
   - Checkpoints can be large (100-500 MB total)
   - Safe to delete once pipeline completes successfully
   - Keep final `ssm_model.mat` forever!

## 🔧 Troubleshooting

### "Phase won't recompute even though I changed config"
```matlab
% Checkpoints override config by design
% Force recompute:
run_pipeline('force', true)

% Or start from specific phase:
run_pipeline('force', true, 'start_from', 2)
```

### "Can't find checkpoint file"
```matlab
% Check if checkpoints are enabled
config = pipeline_config();
config.checkpoint.enabled  % Should be true

% Check if directory exists
exist('cache/checkpoints', 'dir')  % Should be 7
```

### "Out of memory loading checkpoint"
```matlab
% Checkpoints are saved with -v7.3 (HDF5 format)
% If MATLAB crashes, try:
clear all
resume_pipeline()  % Loads only what's needed
```

## 📈 Time Savings Example

Scenario: Testing different PCA component numbers (5, 10, 15, 19)

**Without checkpoints**:
- 4 runs × 82 min = **5.5 hours** 😫

**With checkpoints**:
- First run: 82 min
- Next 3 runs: 3 × 2 min = 6 min
- **Total: 88 min** 🎉

**Savings: 4.4 hours!**
