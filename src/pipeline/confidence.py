from __future__ import annotations

from dataclasses import dataclass
from typing import List, Tuple

from src.pipeline.schema import (
    ConfidenceAssessment,
    DRClassificationResult,
    DRGrade,
)


@dataclass
class ConfidenceConfig:
    """
    Configuration parameters for Confidence and Uncertainty evaluation per Section 7.
    """
    # Top-1 softmax probability threshold (default: 0.60)
    min_confidence_threshold: float = 0.60

    # Margin between Top-1 and Top-2 probabilities (default: 0.15)
    min_ambiguity_margin: float = 0.15

    # Always flag high risk grades (Severe, Proliferative)
    always_flag_high_risk: bool = True


class ConfidenceEvaluator:
    """
    Implements Section 7: Confidence and Uncertainty Handling.
    Decides whether Model 2's prediction is reliable enough to finalize without
    human clinician intervention, or must be flagged for review.
    """

    def __init__(self, config: ConfidenceConfig = None):
        self.config = config or ConfidenceConfig()

    def evaluate(self, dr_result: DRClassificationResult) -> ConfidenceAssessment:
        """
        Evaluates confidence, ambiguity, and clinical risk rules.
        """
        flags: List[str] = []
        is_confident = True
        is_ambiguous = False
        is_high_risk = False
        requires_review = False

        # Rule 1: Low Softmax Confidence Check
        if dr_result.confidence < self.config.min_confidence_threshold:
            is_confident = False
            requires_review = True
            flags.append(
                f"Low confidence ({dr_result.confidence:.1%} < {self.config.min_confidence_threshold:.0%})"
            )

        # Rule 2: Class Ambiguity Check
        if dr_result.top2_margin < self.config.min_ambiguity_margin:
            is_ambiguous = True
            requires_review = True
            flags.append(
                f"Class ambiguity (Top-1/Top-2 margin {dr_result.top2_margin:.2f} < {self.config.min_ambiguity_margin:.2f})"
            )

        # Rule 3: High-Risk Grade Safety Override (Section 7)
        # "A high-risk grade is flagged even if the model is confident, because the
        # clinical cost of a missed Severe/Proliferative case is far higher than the
        # cost of one extra human review."
        if self.config.always_flag_high_risk and dr_result.predicted_grade.is_high_risk:
            is_high_risk = True
            requires_review = True
            flags.append(
                f"High-risk clinical grade ({dr_result.predicted_grade.label}): mandatory ophthalmologist over-read"
            )

        return ConfidenceAssessment(
            is_confident=is_confident,
            is_ambiguous=is_ambiguous,
            is_high_risk=is_high_risk,
            requires_human_review=requires_review,
            flags=flags,
        )
