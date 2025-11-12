# Fix for Topology Mismatch Bug in Registration Phase

## Problem

The SSM pipeline was failing during Phase 2 (Registration) with the error:
```
Unable to perform assignment because the size of the left side is 25891-by-3
and the size of the right side is 31818-by-3.
Location: procrustes_align (line 25)
```

This error occurred because after the registration phase, meshes had inconsistent vertex counts (ranging from 25015 to 36206 vertices), but the Generalized Procrustes Analysis expected all meshes to have the same topology (same number of vertices).

## Root Cause

The non-rigid registration was successfully running, but there was insufficient validation to detect when:
1. Non-rigid registration failed to establish consistent topology
2. Non-rigid registration was disabled but meshes had different topologies from remeshing
3. Individual specimen registration failed silently

## Solution

Added comprehensive validation and error handling at multiple points in the registration pipeline:

### 1. Per-Specimen Validation (run_pipeline.m lines 285-334)
- Added detailed logging showing before/after vertex counts for each specimen
- Added try-catch error handling around non-rigid ICP calls
- Added validation that returned vertices match expected template size
- Added consistency check after each registration iteration

### 2. Non-rigid Disabled Check (run_pipeline.m lines 335-361)
- Added warning when non-rigid registration is disabled
- Added validation that meshes have consistent topology if non-rigid is disabled
- Clear error message with instructions to enable non-rigid registration

### 3. Pre-Procrustes Validation (run_pipeline.m lines 363-382)
- Added final validation before Procrustes Analysis
- Lists all specimen vertex/face counts if inconsistency detected
- Clear error message indicating registration failed

## Changes Made

### File: run_pipeline.m

**Lines 285-334: Enhanced non-rigid registration loop**
- Store original vertex count before registration
- Use intermediate variable `new_vertices` to validate before assignment
- Log each specimen's registration (before/after vertex counts)
- Add error handling with try-catch block
- Validate topology consistency after all specimens registered

**Lines 335-361: Non-rigid disabled check**
- Warn if non-rigid registration is disabled
- Validate topology consistency when non-rigid is disabled
- Provide clear error message with fix instructions

**Lines 363-382: Pre-Procrustes validation**
- Check topology consistency before Procrustes Analysis
- List all specimen topology details if inconsistent
- Fail early with clear error message

## Expected Behavior

With these changes, the pipeline will now:

1. **During registration**: Immediately detect and report any specimen that fails to get proper topology
2. **After each iteration**: Validate that all registered meshes have consistent topology
3. **Before Procrustes**: Final validation with detailed error reporting
4. **If non-rigid disabled**: Warn user and check if topology is already consistent

## Error Messages

The new error messages clearly indicate:
- Which specimen failed registration
- What the expected vs actual vertex counts are
- Whether non-rigid registration needs to be enabled
- Exactly where in the pipeline the inconsistency was detected

## Testing

To test the fix, run the pipeline with:
```matlab
run_pipeline()
```

If topology issues occur, you will now see detailed logging showing:
- Template vertex count
- Each specimen's registration (before/after)
- Exactly which specimen has inconsistent topology
- Clear instructions on how to fix the issue

## Next Steps

If the pipeline still fails with topology inconsistency:
1. Check the detailed logs to see which specimen is failing
2. Verify that `config.registration.use_nonrigid = true`
3. Check that the non-rigid ICP is not encountering numerical issues
4. Verify input meshes are valid (no degenerate faces, etc.)
