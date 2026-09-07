"""
Routing Pipeline and Decision Flow Module.
"""
from src.pipeline.schema import (
    QualityGrade,
    DRGrade,
    ReassessmentOutcome,
    QualityMetrics,
    QualityAssessmentResult,
    DRClassificationResult,
    ConfidenceAssessment,
    GradCAMResult,
    HumanReviewType,
    ScreeningRecord,
)
from src.pipeline.confidence import ConfidenceEvaluator, ConfidenceConfig

__all__ = [
    "QualityGrade",
    "DRGrade",
    "ReassessmentOutcome",
    "QualityMetrics",
    "QualityAssessmentResult",
    "DRClassificationResult",
    "ConfidenceAssessment",
    "GradCAMResult",
    "HumanReviewType",
    "ScreeningRecord",
    "ConfidenceEvaluator",
    "ConfidenceConfig",
    "ScreeningPipelineRouter",
]


def __getattr__(name):
    if name == "ScreeningPipelineRouter":
        from src.pipeline.router import ScreeningPipelineRouter
        return ScreeningPipelineRouter
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
