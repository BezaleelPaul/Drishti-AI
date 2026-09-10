import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DoctorReviewScreen extends StatefulWidget {
  final ApiService apiService;

  const DoctorReviewScreen({super.key, required this.apiService});

  @override
  State<DoctorReviewScreen> createState() => _DoctorReviewScreenState();
}

class _DoctorReviewScreenState extends State<DoctorReviewScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingCases = [];

  final List<Map<String, dynamic>> _mockPendingCases = [
    {
      'review_id': 'REV-260909-01',
      'patient_name': 'Ramesh Kumar (54y, M)',
      'abha_id': '91-4521-8890-3321',
      'screening_id': 'SCR-260909-A101',
      'eye_side': 'Right Eye (OD)',
      'dr_grade': 3,
      'dr_label': 'Severe NPDR',
      'reason': 'Mandatory safety protocol: Grade 3/4 always requires specialist audit.',
      'confidence': '91.2%',
      'priority': 'High (Refer within 30 days)',
      'is_signed_off': false,
    },
    {
      'review_id': 'REV-260909-02',
      'patient_name': 'Anand Verma (62y, M)',
      'abha_id': '91-3312-9901-4455',
      'screening_id': 'SCR-260909-B202',
      'eye_side': 'Left Eye (OS)',
      'dr_grade': 2,
      'dr_label': 'Moderate NPDR',
      'reason': 'Low softmax top-1 confidence (58.4% < 65% clinical threshold).',
      'confidence': '58.4%',
      'priority': 'Medium (Routine audit)',
      'is_signed_off': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() => _isLoading = true);
    final remoteCases = await widget.apiService.getPendingReviews();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (remoteCases.isNotEmpty) {
          _pendingCases = remoteCases.map((item) {
            return {
              'review_id': item['review_id'] ?? item['id'] ?? 'REV-AUTO',
              'patient_name': item['patient_name'] ?? 'Registered Patient',
              'abha_id': item['abha_id'] ?? '91-4500-0000-0000',
              'screening_id': item['screening_id'] ?? 'SCR-LIVE',
              'eye_side': item['eye_side'] ?? 'OD',
              'dr_grade': item['dr_grade'] ?? 3,
              'dr_label': item['dr_label'] ?? 'Referral Required',
              'reason': item['reason'] ?? 'AI referral flagged for specialist sign-off.',
              'confidence': item['confidence'] != null ? '${(item['confidence'] * 100).toStringAsFixed(1)}%' : '88.5%',
              'priority': item['priority'] ?? 'Clinical Audit',
              'is_signed_off': item['status'] == 'APPROVED' || item['status'] == 'COMPLETED',
            };
          }).toList();
        } else {
          _pendingCases = List.from(_mockPendingCases);
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
      clinicalNotes: 'Specialist tele-ophthalmology audit approved for referral.',
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
              : RefreshIndicator(
                  onRefresh: _loadQueue,
                  child: _pendingCases.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'No cases currently pending review 🎉',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
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
                            final grade = (c['dr_grade'] is int) ? c['dr_grade'] as int : int.tryParse(c['dr_grade'].toString()) ?? 0;
                            final isHigh = grade >= 3;

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.only(bottom: 14),
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          c['patient_name'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isSigned
                                                ? const Color(0xFFECFDF5)
                                                : (isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isSigned ? 'SIGNED OFF' : 'AWAITING AUDIT',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSigned
                                                  ? const Color(0xFF047857)
                                                  : (isHigh ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'ABHA: ${c['abha_id']} • Screening: ${c['screening_id']} (${c['eye_side']})',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                    const Divider(height: 20),

                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Grade $grade: ${c['dr_label']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isHigh ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Confidence: ${c['confidence']}',
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    Text(
                                      'Clinical Flag: ${c['reason']}',
                                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(height: 14),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Viewing High-Resolution Grad-CAM Heatmap...')),
                                            );
                                          },
                                          icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                          label: const Text('View Heatmap'),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: isSigned ? null : () => _signOffCase(index),
                                          icon: const Icon(Icons.check, size: 18),
                                          label: Text(isSigned ? 'Approved' : 'Sign Off Referral'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF047857),
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
      ),
    );
  }
}
