import 'package:flutter/material.dart';

class SystemSpecsScreen extends StatelessWidget {
  final bool embedded;
  const SystemSpecsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final specsBody = Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.memory_rounded, color: Colors.cyanAccent, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'On-Device Edge Screening Architecture',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manufacturer-agnostic pipeline running low-latency clinical deep learning locally on mobile/tablet edge hardware without mandatory internet connectivity.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AI Models Stack
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🧠 Dual-Model Edge Deep Learning Stack',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 14),

                      _buildSpecRow(
                        'Model 1: Quality Gate',
                        'Deep Ensemble (berenslab/fundus_image_toolbox) + Laplacian Fusion',
                        '~42 ms edge latency | Certifies sharpness, FOV & illumination before grading',
                        Icons.verified_rounded,
                        const Color(0xFF059669),
                      ),
                      const Divider(height: 24),

                      _buildSpecRow(
                        'Model 2: DR Classifier',
                        'EfficientNetB0 (Fine-tuned on APTOS 2019 / EyePACS, 5-class severity)',
                        '~118 ms edge latency | Softmax probabilities + CSME macular edema biomarker',
                        Icons.science_rounded,
                        const Color(0xFF1E3A8A),
                      ),
                      const Divider(height: 24),

                      _buildSpecRow(
                        'Explainability Engine',
                        'Grad-CAM++ (Higher-Order Gradient Feature Attribution Map)',
                        '~86 ms edge latency | Localizes microaneurysms, hard exudates & hemorrhages',
                        Icons.visibility_rounded,
                        const Color(0xFFD97706),
                      ),
                      const Divider(height: 24),

                      _buildSpecRow(
                        'Upstream Risk Engine',
                        'ICMR / Google-Aravind Calibrated Non-Invasive Diabetes Risk Tree',
                        '<10 ms latency | Flags high-risk patients upstream using age, BMI, family history',
                        Icons.health_and_safety_rounded,
                        const Color(0xFFDC2626),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Multi-Camera Profiles
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📷 Manufacturer-Agnostic Camera Compatibility',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 14),

                      _buildCameraItem(
                        'Forus 3nethra Classic',
                        'Forus Health (India)',
                        'Non-mydriatic tabletop camera deployed across Indian PHCs (2048x1536, 45° FOV)',
                      ),
                      const Divider(height: 18),

                      _buildCameraItem(
                        'Remidio FOP (Fundus on Phone)',
                        'Remidio Innovative Solutions',
                        'Handheld smartphone fundus camera ideal for ASHA workers and rural vans (45° FOV)',
                      ),
                      const Divider(height: 18),

                      _buildCameraItem(
                        'Volk iNview',
                        'Volk Optical',
                        'Smartphone 20D indirect ophthalmoscopy condensing lens attachment (50° FOV)',
                      ),
                      const Divider(height: 18),

                      _buildCameraItem(
                        'Clinical Desktop Fundus Cameras',
                        'Zeiss, Topcon, Canon, Kowa',
                        'Standard hospital DICOM / high-resolution RGB fundus photography',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Interoperability & ABDM Gateway
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🌐 Standards & ABDM Interoperability',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ABDM FHIR R4 DiagnosticReport JSON bundles with ABHA token exchange',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ICD-10 Standardized Codification (E11.319 to E11.359) for automated EHR integration',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Store-and-Forward SQLite sync cache for zero data loss in offline rural zones',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );

    if (embedded) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: specsBody,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('System Specs & Hardware Profiles'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: specsBody,
    );
  }

  Widget _buildSpecRow(String title, String subtitle, String details, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraItem(String name, String manufacturer, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                manufacturer,
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
