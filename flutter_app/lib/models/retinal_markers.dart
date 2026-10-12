class MarkerCircle {
  final int x;
  final int y;
  final int r;

  MarkerCircle({required this.x, required this.y, required this.r});

  factory MarkerCircle.fromJson(Map<String, dynamic> json) => MarkerCircle(
    x: (json['x'] as num?)?.toInt() ?? 0,
    y: (json['y'] as num?)?.toInt() ?? 0,
    r: (json['r'] as num?)?.toInt() ?? 0,
  );
}

class MarkerPoint {
  final int x;
  final int y;

  MarkerPoint({required this.x, required this.y});

  factory MarkerPoint.fromJson(Map<String, dynamic> json) => MarkerPoint(
    x: (json['x'] as num?)?.toInt() ?? 0,
    y: (json['y'] as num?)?.toInt() ?? 0,
  );
}

class RetinalMarkers {
  static const String classicalCvSource = 'classical_cv_segmentation';

  final String reviewId;
  // Honesty invariant: available=false (could not compute) is a DIFFERENT
  // state from available=true with an empty maCandidates list (healthy
  // retina, no lesion candidates). Never conflate the two.
  final bool available;
  final String? reason;
  // Provenance pinned to classical CV segmentation — never model attention,
  // Grad-CAM, or a diagnosis (Req 2.2). Not settable by callers; fromJson
  // rejects any other value.
  final String source;
  final int width;
  final int height;
  final MarkerCircle? opticDisc;
  final MarkerPoint? fovea;
  // Coordinates only — no vessel/exudate mask data in this payload. Always
  // present; explicitly empty when there are no candidates (never null).
  final List<MarkerCircle> maCandidates;

  RetinalMarkers({
    required this.reviewId,
    required this.available,
    this.reason,
    this.width = 0,
    this.height = 0,
    this.opticDisc,
    this.fovea,
    this.maCandidates = const [],
  }) : source = classicalCvSource;

  factory RetinalMarkers.fromJson(Map<String, dynamic> json) {
    final source = json['source'];
    if (source != null && source != classicalCvSource) {
      throw FormatException('Unsupported marker source: $source');
    }
    return RetinalMarkers(
      reviewId: (json['review_id'] ?? '').toString(),
      available: json['available'] as bool? ?? false,
      reason: json['reason']?.toString(),
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      opticDisc: json['optic_disc'] == null
          ? null
          : MarkerCircle.fromJson(json['optic_disc'] as Map<String, dynamic>),
      fovea: json['fovea'] == null
          ? null
          : MarkerPoint.fromJson(json['fovea'] as Map<String, dynamic>),
      maCandidates: json['ma_candidates'] is List
          ? (json['ma_candidates'] as List)
                .map((e) => MarkerCircle.fromJson(e as Map<String, dynamic>))
                .toList()
          : const [],
    );
  }
}
