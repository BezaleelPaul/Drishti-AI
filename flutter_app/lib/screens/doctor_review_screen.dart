import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DoctorReviewScreen extends StatefulWidget {
  final ApiService apiService;

  final bool embedded;

  const DoctorReviewScreen({
    super.key,
    required this.apiService,
    this.embedded = false,
  });

  @override
  State<DoctorReviewScreen> createState() => _DoctorReviewScreenState();
}

class _DoctorReviewScreenState extends State<DoctorReviewScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingCases = [];
  String? _authNotice;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
      _authNotice = null;
    });
    List<Map<String, dynamic>> remoteCases = [];
    try {
      remoteCases = await widget.apiService.getPendingReviews();
    } on ReviewAuthException catch (e) {
      // Operator key on a doctor-only endpoint: say so instead of
      // rendering a fake "empty queue".
      _authNotice = e.message;
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (remoteCases.isNotEmpty) {
          _pendingCases = remoteCases.map((item) {
            final rawGrade = item['dr_grade'];
            final int? parsedGrade = rawGrade == null
                ? null
                : (rawGrade is int
                      ? rawGrade
                      : int.tryParse(rawGrade.toString()));
            final rawConf = item['confidence'];
            final String confidenceStr = rawConf != null
                ? '${(rawConf * 100).toStringAsFixed(1)}%'
                : 'N/A';
            return {
              'review_id': item['review_id'] ?? item['id'] ?? 'Unknown',
              'patient_name': item['patient_name'] ?? 'Unknown',
              'abha_id': item['abha_id'] ?? 'Unknown',
              'screening_id': item['screening_id'] ?? 'Unknown',
              'eye_side': item['eye_side'] ?? 'Unknown',
              'dr_grade': parsedGrade,
              'dr_label': item['dr_label'] ?? 'Unknown',
              'reason': item['reason'] ?? 'No reason provided by AI backend.',
              'confidence': confidenceStr,
              'priority': item['priority'] ?? 'Review Required',
              'is_signed_off':
                  item['status'] == 'APPROVED' || item['status'] == 'COMPLETED',
            };
          }).toList();
        } else {
          // No remote cases and no cached queue: truly nothing to review.
          // Do NOT inject mock patient data — that would present fabricated
          // clinical records as real.
          _pendingCases = [];
        }
      });
    }
  }

  Future<void> _signOffCase(int index) async {
    final caseItem = _pendingCases[index];
    final revId = caseItem['review_id'].toString();

    // Optimistically update
    setState(() {
      _pendingCases[index]['is_signed_off'] = true;
    });

    await widget.apiService.submitDoctorDecision(
      reviewId: revId,
      doctorName: 'Dr. Sharma (MS Ophth)',
      decision: 'CONFIRMED',
      clinicalNotes:
          'Specialist tele-ophthalmology audit approved for referral.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Case $revId successfully signed off by Ophthalmologist.',
          ),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueBody = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
              )
            : RefreshIndicator(
                onRefresh: _loadQueue,
                child: _pendingCases.isEmpty
                    ? ListView(
                        children: [
                          if (_authNotice != null)
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                              child: Text(
                                _authNotice!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              'No cases currently pending review 🎉',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendingCases.length,
                        itemBuilder: (context, index) {
                          final c = _pendingCases[index];
                          final isSigned = (c['is_signed_off'] == true);
                          final grade = (c['dr_grade'] is int)
                              ? c['dr_grade'] as int
                              : int.tryParse(c['dr_grade'].toString()) ?? 0;
                          final isHigh = grade >= 3;

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(bottom: 14),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        c['patient_name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSigned
                                              ? const Color(0xFFECFDF5)
                                              : (isHigh
                                                    ? const Color(0xFFFEE2E2)
                                                    : const Color(0xFFFEF3C7)),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          isSigned
                                              ? 'SIGNED OFF'
                                              : 'AWAITING AUDIT',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isSigned
                                                ? const Color(0xFF047857)
                                                : (isHigh
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(
                                                          0xFFD97706,
                                                        )),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'ABHA: ${c['abha_id']} • Screening: ${c['screening_id']} (${c['eye_side']})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const Divider(height: 20),

                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isHigh
                                              ? const Color(0xFFFEE2E2)
                                              : const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Grade $grade: ${c['dr_label']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isHigh
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF1E3A8A),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Confidence: ${c['confidence']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  Text(
                                    'Clinical Flag: ${c['reason']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Viewing High-Resolution Grad-CAM Heatmap...',
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.remove_red_eye_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('View Heatmap'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: isSigned
                                            ? null
                                            : () => _signOffCase(index),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: Text(
                                          isSigned
                                              ? 'Approved'
                                              : 'Sign Off Referral',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF047857,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_services_rounded,
                    color: Color(0xFF1E3A8A),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tele-Ophthalmologist Review Queue',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
                    tooltip: 'Refresh Queue',
                    onPressed: _loadQueue,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: queueBody),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tele-Ophthalmologist Review Queue'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Queue',
            onPressed: _loadQueue,
          ),
        ],
      ),
      body: queueBody,
    );
  }
}
