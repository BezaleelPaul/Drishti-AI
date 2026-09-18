"""
Routing Pipeline and Decision Flow Module.
"""
from src.pipeline.confidence import ConfidenceConfig, ConfidenceEvaluator
from src.pipeline.schema import (
    ConfidenceAssessment,
    DRClassificationResult,
    DRGrade,
    GradCAMResult,
    HumanReviewType,
    QualityAssessmentResult,
    QualityGrade,
    QualityMetrics,
    ReassessmentOutcome,
    ScreeningRecord,
)

__all__ = [
    "ConfidenceAssessment",
    "ConfidenceConfig",
    "ConfidenceEvaluator",
    "DRClassificationResult",
    "DRGrade",
    "GradCAMResult",
    "HumanReviewType",
    "QualityAssessmentResult",
    "QualityGrade",
    "QualityMetrics",
    "ReassessmentOutcome",
    "ScreeningPipelineRouter",
    "ScreeningRecord",
]


def __getattr__(name):
    if name == "ScreeningPipelineRouter":
        from src.pipeline.router import ScreeningPipelineRouter
        return ScreeningPipelineRouter
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
