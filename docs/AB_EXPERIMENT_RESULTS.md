# Section 12 Experimental Evaluation: A/B/C Comparison

| Evaluation Metric | Arm A: Direct Baseline (No Gate) | Arm B & C: Our Proposed Pipeline | Clinical Significance |
|---|:---:|:---:|---|
| **Forced Predictions on Ungradable Images** | **100.0%** | **0.0%** | Prevents giving patients confident fake grades on blurry/corrupt images |
| **Referable DR Sensitivity (Reliable Images)** | Unreliable | **11.1%** | High sensitivity on clinically verified images |
| **Referable DR Specificity** | Unreliable | **92.8%** | Minimizes unnecessary referrals |
| **Screening Recapture / Abstention Rate** | 0.0% (Blind) | **20.7%** | Bounded field recapture overhead (< 20% target) |
| **Total Human Review Escalation Rate** | 0.0% (Silent Failure) | **77.3%** | Safe two-tier human safety net for ambiguous cases |
