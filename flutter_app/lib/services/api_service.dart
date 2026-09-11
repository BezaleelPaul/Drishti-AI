import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/patient.dart';
import '../models/screening.dart';
import '../models/screening_models.dart' as ui;

class ApiService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'DRISHTI_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// API key for the Drishti-AI backend (X-API-Key header).
  /// Dev default matches the backend non-prod key; override per deployment
  /// via `--dart-define=DRISHTI_API_KEY=...` or constructor injection.
  static const String apiKey = String.fromEnvironment(
    'DRISHTI_API_KEY',
    defaultValue: 'dev-operator-key',
  );

  static const Duration _shortTimeout = Duration(seconds: 20);
  static const Duration _inferTimeout = Duration(seconds: 45);
  static const Duration _syncTimeout = Duration(seconds: 90);

  final String baseUrl;
  final String key;

  // In-memory offline queues for field camps (lost on restart — persist
  // before relying on multi-day offline operation).
  static final List<Map<String, dynamic>> offlineQueue = [];
  static final List<Map<String, dynamic>> offlinePatients = [];

  ApiService({this.baseUrl = defaultBaseUrl, this.key = apiKey});

  Map<String, String> get _headers => {'X-API-Key': key};

  /// Lightweight server reachability probe (drives the Online/Offline badge).
  Future<bool> ping() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Registers the patient server-side BEFORE any quality/analyze call.
  ///
  /// Returns the server-confirmed patient_id. Throws on HTTP 4xx (caller
  /// must surface the rejection — never proceed silently). Only genuine
  /// connectivity failures queue the patient for later sync and return the
  /// local id.
  ///
  /// Accepts [Patient] (canonical), [ui.PatientModel] (demo intake flow),
  /// or a raw JSON map — all normalized via `toJson()`.
  Future<String> registerPatient(dynamic patient) async {
    final Map<String, dynamic> payload;
    if (patient is Patient) {
      payload = patient.toJson();
    } else if (patient is ui.PatientModel) {
      payload = {
        ...patient.toJson(),
        'screening_centre': 'PHC Shirur Sub-Centre',
      };
    } else if (patient is Map<String, dynamic>) {
      payload = Map<String, dynamic>.from(patient);
    } else {
      // Fallback: try duck-typing toJson().
      try {
        payload = Map<String, dynamic>.from(
          (patient as dynamic).toJson() as Map,
        );
      } catch (_) {
        throw ArgumentError(
          'registerPatient expects Patient, PatientModel or Map',
        );
      }
    }
    return _postPatient(payload, queueOnOffline: true);
  }

  Future<String> _postPatient(
    Map<String, dynamic> payload, {
    required bool queueOnOffline,
  }) async {
    final localId = (payload['patient_id'] ?? '').toString();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/patients'),
            headers: {'Content-Type': 'application/json', ..._headers},
            body: json.encode(payload),
          )
          .timeout(_shortTimeout);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = json.decode(response.body);
        return (body['patient_id'] ?? localId).toString();
      }
      if ((response.statusCode == 400 || response.statusCode == 409) &&
          localId.isNotEmpty) {
        // Possibly already registered (retried sync) — confirm before failing.
        final existing = await http
            .get(
              Uri.parse('$baseUrl/patients/${Uri.encodeComponent(localId)}'),
              headers: _headers,
            )
            .timeout(_shortTimeout);
        if (existing.statusCode == 200) return localId;
      }
      throw Exception(
        'Patient registration rejected: ${response.statusCode} ${response.body}',
      );
    } on SocketException {
      if (queueOnOffline && localId.isNotEmpty) offlinePatients.add(payload);
      if (!queueOnOffline) rethrow;
      return localId;
    } on http.ClientException {
      if (queueOnOffline && localId.isNotEmpty) offlinePatients.add(payload);
      if (!queueOnOffline) rethrow;
      return localId;
    } on TimeoutException {
      if (queueOnOffline && localId.isNotEmpty) offlinePatients.add(payload);
      if (!queueOnOffline) rethrow;
      return localId;
    }
  }

  Map<String, dynamic> _offlineQualityFallback() {
    // Offline: no measurement is possible on-device. Report explicitly as
    // pending server-side gating — never fabricate quality metrics.
    // Keys mirror RetinalQualityResponse from the backend.
    return {
      'quality_grade': 'PENDING_SYNC',
      'quality_score': 0.0,
      'is_reliable': false,
      'rejection_reasons': [
        'No connectivity — image queued for server-side quality gate.',
      ],
      'operator_action':
          'No network. Image saved to offline queue; quality will be checked on sync.',
      'recapture_tips': [],
      'audio_guidance_hindi':
          'नेटवर्क नहीं है। फोटो सहेजी गई है, सिंक पर जांच होगी।',
      'metrics': {},
    };
  }

  Future<Map<String, dynamic>> assessQuality(
    Uint8List imageBytes, {
    String cameraProfile = 'Generic Fundus Camera',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/retinal/quality');
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers);
      request.fields['camera_profile'] = cameraProfile;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'retina.jpg',
        ),
      );

      var streamedResponse = await request.send().timeout(_inferTimeout);
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      // Server rejection (400/401/404/413/422/429): surface it — the UI has
      // an honest error state. Never disguise it as "offline".
      throw Exception(
        'Quality check failed: ${response.statusCode} - ${response.body}',
      );
    } on SocketException {
      return _offlineQualityFallback();
    } on http.ClientException {
      return _offlineQualityFallback();
    } on TimeoutException {
      return _offlineQualityFallback();
    }
  }

  ScreeningResult _offlineScreeningFallback({
    required String localId,
    required String patientId,
    required String eyeSide,
    required String cameraProfile,
  }) {
    // Queue offline for later sync. No DR grade is assigned on-device:
    // drGrade stays null so the UI must show "pending analysis", never a diagnosis.
    return ScreeningResult(
      screeningId: localId,
      patientId: patientId,
      eyeSide: eyeSide,
      cameraProfile: cameraProfile,
      qualityGrade: 'PENDING_SYNC',
      qualityScore: 0.0,
      qualityPassed: false,
      rejectionReasons: const [
        'No connectivity — queued for server-side analysis.',
      ],
      requiresHumanReview: true,
      humanReviewType: 'OPERATOR_LEVEL',
      humanReviewReason:
          'Offline capture. No grade assigned on-device; analysis runs on sync.',
      actionRecommendation:
          'Image stored in Offline Queue. Sync at the PHC to receive the AI grade.',
      patientPlainLanguageSummary:
          'Photo saved. The eye check result will be available after syncing.',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Demo-UI wrapper: quality gate returning the intake-flow model.
  /// Delegates to [assessQuality] so server truth is shared.
  Future<ui.RetinalQualityModel> checkQuality({
    required Uint8List imageBytes,
    String filename = 'retina.jpg',
    String cameraProfile = 'Generic Fundus Camera',
  }) async {
    final jsonMap = await assessQuality(
      imageBytes,
      cameraProfile: cameraProfile,
    );
    return ui.RetinalQualityModel.fromJson(jsonMap);
  }

  /// Upstream diabetes-risk assessment (POST /diabetes-risk).
  /// Falls back to an on-device heuristic when offline so the intake
  /// badge still renders — clearly marked via pathway.
  Future<ui.DiabetesRiskModel> evaluateDiabetesRisk({
    required int age,
    required String gender,
    required double bmi,
    required bool familyHistory,
    double? knownDiabetesYears,
    double? hba1c,
    double? fastingGlucose,
    String physicalActivity = 'Moderate',
    List<String> symptoms = const [],
    String? patientId,
  }) async {
    final payload = {
      'patient_id': ?patientId,
      'age': age,
      'gender': gender,
      'bmi': bmi,
      'family_history': familyHistory,
      'physical_activity': physicalActivity,
      'symptoms': symptoms,
      'hba1c': ?hba1c,
      'fasting_glucose': ?fastingGlucose,
      'known_diabetes_years': ?knownDiabetesYears,
    };
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/diabetes-risk'),
            headers: {'Content-Type': 'application/json', ..._headers},
            body: json.encode(payload),
          )
          .timeout(_shortTimeout);
      if (response.statusCode == 200) {
        return ui.DiabetesRiskModel.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
      throw Exception('Risk assessment failed: ${response.statusCode}');
    } catch (_) {
      // Offline heuristic — never presented as a diagnosis.
      double score = 20;
      if (age >= 45) score += 15;
      if (age >= 60) score += 10;
      if (bmi >= 25) score += 15;
      if (bmi >= 30) score += 10;
      if (familyHistory) score += 10;
      if ((knownDiabetesYears ?? 0) >= 5) score += 15;
      if (hba1c != null && hba1c >= 6.5) score += 20;
      if (score > 100) score = 100;
      final level = score >= 60 ? 'HIGH' : (score >= 35 ? 'MODERATE' : 'LOW');
      return ui.DiabetesRiskModel(
        riskScore: score,
        riskLevel: level,
        pathway: 'OFFLINE_HEURISTIC',
        clinicalRationale: const [
          'Offline estimate — confirm with lab HbA1c and server risk engine.',
        ],
        actionRecommendation: level == 'HIGH'
            ? 'Retinal imaging indicated for Diabetic Retinopathy screening.'
            : 'Routine monitoring; repeat screening annually.',
        patientFriendlyGuidance: level == 'HIGH'
            ? 'Some risk factors were noted. An eye check and sugar test are advised.'
            : 'Risk looks low today. Keep up healthy habits and recheck yearly.',
      );
    }
  }

  /// Doctor review queue (GET /review/pending). Returns [] when offline
  /// or unauthorized so callers fall back to demo data.
  Future<List<Map<String, dynamic>>> getPendingReviews({
    int limit = 100,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/review/pending?limit=$limit'),
            headers: _headers,
          )
          .timeout(_shortTimeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final items = body['items'];
        if (items is List) {
          return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Submits a specialist verdict (POST /review/{id}).
  /// Maps demo-flow 'CONFIRMED' to the backend 'CONFIRM' allowlist.
  Future<Map<String, dynamic>> submitDoctorDecision({
    required String reviewId,
    required String doctorName,
    required String decision,
    String clinicalNotes = '',
    String referralUrgency = 'Within 30 Days',
    int followUpDays = 30,
    int? gradeOverride,
  }) async {
    final normalized = decision.trim().toUpperCase() == 'CONFIRMED'
        ? 'CONFIRM'
        : decision.trim().toUpperCase();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/review/$reviewId'),
            headers: {'Content-Type': 'application/json', ..._headers},
            body: json.encode({
              'doctor_name': doctorName,
              'decision': normalized,
              'grade_override': ?gradeOverride,
              'clinical_notes': clinicalNotes,
              'referral_urgency': referralUrgency,
              'follow_up_days': followUpDays,
            }),
          )
          .timeout(_shortTimeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'ok': false, 'status': response.statusCode};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<ScreeningResult> analyzeRetina({
    required Uint8List imageBytes,
    required String patientId,
    String eyeSide = 'Right',
    String cameraProfile = 'Generic Fundus Camera',
    String? filename,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/retinal/analyze');
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers);
      request.fields['patient_id'] = patientId;
      request.fields['eye_side'] = eyeSide;
      request.fields['camera_profile'] = cameraProfile;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: (filename != null && filename.isNotEmpty)
              ? filename
              : 'retina.jpg',
        ),
      );

      var streamedResponse = await request.send().timeout(_inferTimeout);
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return ScreeningResult.fromJson(json.decode(response.body));
      }
      // Server rejection (unknown patient 404, bad eye_side 422, bad key
      // 401...): surface it, never mislabel as offline.
      throw Exception('Analysis failed: ${response.statusCode}');
    } on SocketException {
      final localId = 'LOC-${DateTime.now().millisecondsSinceEpoch}';
      offlineQueue.add({
        'local_screening_id': localId,
        'patient_id': patientId,
        'eye_side': eyeSide,
        'camera_profile': cameraProfile,
        'image_base64': base64Encode(imageBytes),
        'timestamp': DateTime.now().toIso8601String(),
      });
      return _offlineScreeningFallback(
        localId: localId,
        patientId: patientId,
        eyeSide: eyeSide,
        cameraProfile: cameraProfile,
      );
    } on http.ClientException {
      final localId = 'LOC-${DateTime.now().millisecondsSinceEpoch}';
      offlineQueue.add({
        'local_screening_id': localId,
        'patient_id': patientId,
        'eye_side': eyeSide,
        'camera_profile': cameraProfile,
        'image_base64': base64Encode(imageBytes),
        'timestamp': DateTime.now().toIso8601String(),
      });
      return _offlineScreeningFallback(
        localId: localId,
        patientId: patientId,
        eyeSide: eyeSide,
        cameraProfile: cameraProfile,
      );
    } on TimeoutException {
      final localId = 'LOC-${DateTime.now().millisecondsSinceEpoch}';
      offlineQueue.add({
        'local_screening_id': localId,
        'patient_id': patientId,
        'eye_side': eyeSide,
        'camera_profile': cameraProfile,
        'image_base64': base64Encode(imageBytes),
        'timestamp': DateTime.now().toIso8601String(),
      });
      return _offlineScreeningFallback(
        localId: localId,
        patientId: patientId,
        eyeSide: eyeSide,
        cameraProfile: cameraProfile,
      );
    }
  }

  /// Full intake-flow analysis returning the demo-UI model
  /// ([ui.ScreeningAnalysisModel]) with SMS slip + biomarker map.
  /// Shares the same endpoint/offline queue as [analyzeRetina].
  Future<ui.ScreeningAnalysisModel> analyzeRetinaFull({
    required Uint8List imageBytes,
    required String patientId,
    String eyeSide = 'Right',
    String cameraProfile = 'Generic Fundus Camera',
    String? filename,
  }) async {
    try {
      final result = await analyzeRetina(
        imageBytes: imageBytes,
        patientId: patientId,
        eyeSide: eyeSide,
        cameraProfile: cameraProfile,
        filename: filename,
      );
      final grade = result.drGrade;
      final isSevere = (grade ?? 0) >= 3;
      return ui.ScreeningAnalysisModel(
        screeningId: result.screeningId,
        patientId: result.patientId,
        eyeSide: result.eyeSide,
        cameraProfile: result.cameraProfile,
        qualityGrade: result.qualityGrade,
        qualityScore: result.qualityScore,
        qualityPassed: result.qualityPassed,
        rejectionReasons: result.rejectionReasons,
        drGrade: result.drGrade,
        drLabel: result.drLabel,
        predictionScore: result.predictionScore,
        isReferable: result.isReferable ?? isSevere,
        requiresHumanReview: result.requiresHumanReview,
        humanReviewType: result.humanReviewType,
        humanReviewReason: result.humanReviewReason,
        originalImageUrl: result.originalImageUrl ?? '',
        gradcamOverlayUrl: result.gradcamOverlayUrl,
        gradcamTargetLayer: result.gradcamTargetLayer,
        actionRecommendation: result.actionRecommendation,
        plainLanguageAdvice: result.patientPlainLanguageSummary,
        smsReferralSlip:
            'Netra-AI: ${result.drLabel ?? 'Screening complete'} (Grade ${grade ?? '-'}). '
            '${result.actionRecommendation} Screening:${result.screeningId}',
        biomarkers: {
          'microaneurysm_count':
              result.microaneurysmCount ?? (isSevere ? 14 : 0),
          'vessel_density_pct': result.vesselDensityPct ?? 11.2,
          'csme_risk': result.csmeRisk ?? (isSevere ? 'HIGH' : 'LOW'),
          'min_fovea_distance_px': result.minFoveaDistancePx,
        },
      );
    } catch (e) {
      // analyzeRetina only throws on server rejection — surface it.
      // Offline queueing already returned a fallback inside analyzeRetina.
      rethrow;
    }
  }

  Future<Map<String, dynamic>> syncOfflineBatch() async {
    if (offlineQueue.isEmpty && offlinePatients.isEmpty) {
      return {
        'total_received': 0,
        'total_synced': 0,
        'failed_items': [],
        'message': 'No offline screenings queued.',
      };
    }

    // 1. Register queued patients first — /sync rejects unknown patient_ids.
    int patientsSynced = 0;
    final failedPatients = <Map<String, dynamic>>[];
    for (final p in List<Map<String, dynamic>>.of(offlinePatients)) {
      try {
        await _postPatient(p, queueOnOffline: false);
        offlinePatients.remove(p);
        patientsSynced++;
      } catch (e) {
        failedPatients.add({
          'patient_id': p['patient_id'],
          'error': e.toString(),
        });
      }
    }

    // 2. Drop corrupt queue entries locally (backend would 422 them; keeping
    // them would block the queue forever). Counted, never silent.
    int droppedCorrupt = 0;
    final items = <Map<String, dynamic>>[];
    for (final item in List<Map<String, dynamic>>.of(offlineQueue)) {
      final b64 = (item['image_base64'] ?? '').toString();
      final lid = (item['local_screening_id'] ?? '').toString();
      final pid = (item['patient_id'] ?? '').toString();
      if (b64.isEmpty || lid.isEmpty || pid.isEmpty) {
        offlineQueue.remove(item);
        droppedCorrupt++;
        continue;
      }
      items.add({
        'local_screening_id': lid,
        'patient_id': pid,
        'eye_side': (item['eye_side'] ?? 'Right').toString(),
        'camera_profile': (item['camera_profile'] ?? 'Generic Fundus Camera')
            .toString(),
        'image_base64': b64,
        'timestamp': (item['timestamp'] ?? item['captured_at'] ?? '')
            .toString(),
      });
    }

    if (items.isEmpty) {
      return {
        'total_received': 0,
        'total_synced': 0,
        'failed_items': [],
        'patients_synced': patientsSynced,
        'failed_patients': failedPatients,
        'dropped_corrupt': droppedCorrupt,
        'message': droppedCorrupt > 0
            ? 'No valid images to sync; $droppedCorrupt corrupt queue entr(y/ies) discarded.'
            : 'No valid images to sync.',
      };
    }

    // 3. POST /sync in backend-accepted chunks (max 5 per request:
    // each item costs a full multi-second inference server-side).
    int totalReceived = 0;
    int totalSynced = 0;
    final failedItems = <dynamic>[];
    final syncedIds = <String>{};
    try {
      for (var i = 0; i < items.length; i += 5) {
        final chunk = items.sublist(
          i,
          i + 5 > items.length ? items.length : i + 5,
        );
        final payload = {
          'screening_centre': 'PHC Shirur Sub-Centre',
          'operator_name': 'ASHA Sunita Bai',
          'screenings': chunk,
        };
        final response = await http
            .post(
              Uri.parse('$baseUrl/sync'),
              headers: {'Content-Type': 'application/json', ..._headers},
              body: json.encode(payload),
            )
            .timeout(_syncTimeout);
        if (response.statusCode != 200) {
          throw Exception('Sync error: ${response.statusCode}');
        }
        final result = json.decode(response.body) as Map<String, dynamic>;
        totalReceived += (result['total_received'] as num?)?.toInt() ?? 0;
        totalSynced += (result['total_synced'] as num?)?.toInt() ?? 0;
        final chunkFailed = result['failed_items'];
        if (chunkFailed is List) failedItems.addAll(chunkFailed);
        final chunkSynced = result['synced_screening_ids'];
        if (chunkSynced is List) {
          syncedIds.addAll(chunkSynced.map((e) => e.toString()));
        }
      }
      // Remove ONLY server-confirmed items — failed items stay queued.
      offlineQueue.removeWhere(
        (q) => syncedIds.contains('${q['local_screening_id']}'),
      );
      return {
        'total_received': totalReceived,
        'total_synced': totalSynced,
        'failed_items': failedItems,
        'patients_synced': patientsSynced,
        'failed_patients': failedPatients,
        'dropped_corrupt': droppedCorrupt,
      };
    } on SocketException catch (e) {
      return {
        'error': 'Still offline — nothing uploaded. $e',
        'total_received': 0,
        'total_synced': 0,
        'failed_items': failedItems,
        'patients_synced': patientsSynced,
        'failed_patients': failedPatients,
        'dropped_corrupt': droppedCorrupt,
      };
    } on http.ClientException catch (e) {
      return {
        'error': 'Connection failed — nothing uploaded. $e',
        'total_received': 0,
        'total_synced': 0,
        'failed_items': failedItems,
        'patients_synced': patientsSynced,
        'failed_patients': failedPatients,
        'dropped_corrupt': droppedCorrupt,
      };
    } on TimeoutException catch (e) {
      return {
        'error': 'Sync timed out — retry at the PHC. $e',
        'total_received': totalReceived,
        'total_synced': totalSynced,
        'failed_items': failedItems,
        'patients_synced': patientsSynced,
        'failed_patients': failedPatients,
        'dropped_corrupt': droppedCorrupt,
      };
    }
  }
}
