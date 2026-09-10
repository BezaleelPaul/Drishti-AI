# Bug Fixes in Drishti-AI Project

## Summary
Fixed 5 bugs across the codebase affecting quality checking, classification, routing, risk assessment, and error handling.

## Bugs Fixed

### 1. Hardcoded Sharpness Threshold (src/quality/checker.py)
- **Issue**: Line 444 used hardcoded `55.0` for blur threshold in sigmoid calculation
- **Impact**: Reduced configurability and made maintenance difficult
- **Fix**: Changed to use `th.blur_good_threshold` to respect the dynamic thresholds configuration
- **Lines**: 447-448

### 2. Seed Calculation in Simulated Classification (src/classification/classifier.py)
- **Issue**: Only used red channel mean and std, leading to similar probabilities for visually different images
- **Impact**: Reduced randomness and determinism in simulated predictions
- **Fix**: Added green and blue channel means to create more unique image hashes
- **Lines**: 161-163

### 3. Recapture Attempt Messaging (src/pipeline/router.py)
- **Issue**: Borderline reassessment failure didn't show recapture attempt number
- **Impact**: Poor user experience, operators don't know how many attempts remain
- **Fix**: Changed message to include `#{recapture_attempt_count + 1}/{MAX_RECAPTURE_CAP}`
- **Lines**: 150-152

### 4. Feature Column Validation (src/clinical_risk/risk_model.py)
- **Issue**: No validation that feature columns match model expectations
- **Impact**: Could cause silent failures or incorrect risk predictions if column count mismatched
- **Fix**: Added validation to check `len(self.feature_cols) == len(features.columns)`
- **Lines**: 95-98

### 5. Variable Scope Issue in Checker (src/quality/checker.py)
- **Issue**: `th` variable defined in `assess_image` not accessible in `_calculate_metrics`
- **Impact**: TypeError when ML quality calculation attempted to use threshold values
- **Fix**: Changed method signature to accept `th` parameter and passed it from caller
- **Lines**: 215, 217

### 6. Variable Scope for ML Score (src/quality/checker.py)
- **Issue**: `ml_score` variable defined in `_calculate_metrics` not accessible in `assess_image`
- **Impact**: NameError when checking ML quality thresholds
- **Fix**: Changed all references to use `metrics.raw_scores.get("ml_quality_score", 0.0 or 1.0)`
- **Lines**: 262, 285, 312-313, 323, 333

## Test Results
- Unit tests: 10/10 passed ✓
- Integration tests: 8/8 passed ✓
- Total tests: 18/18 passed ✓

## Files Modified
1. src/quality/checker.py (5 fixes)
2. src/classification/classifier.py (1 fix)
3. src/pipeline/router.py (1 fix)
4. src/clinical_risk/risk_model.py (1 fix)
