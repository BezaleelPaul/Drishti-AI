import 'package:flutter/material.dart';

import '../l10n/lang_scope.dart';
import '../services/api_service.dart';
import '../services/db/local_store.dart';
import '../services/offline_queue_service.dart';
import '../theme/figma_theme.dart';
import '../widgets/scanner/scanner_theme.dart';
import '../widgets/status_badge.dart';
import 'figma_dashboard_screen.dart';

/// Patient History — real longitudinal records only, dark HUD chrome
/// consistent with the clinical shell. Server rows when the screening
/// service is reachable; otherwise the screenings recorded on this device
/// via LocalStore. There is no fabricated fallback: with no records on
/// either source the screen shows an honest empty state.
class FigmaHistoryScreen extends StatefulWidget {
  const FigmaHistoryScreen({super.key});

  @override
  State<FigmaHistoryScreen> createState() => _FigmaHistoryScreenState();
}

class _FigmaHistoryScreenState extends State<FigmaHistoryScreen> {
  bool _loading = true;
  bool _fromServer = false;
  List<(String, String, String, String, FigmaStatus)> _rows = const [];

  @override
  void initState() {
    super.initState();
    unawaitedLoad();
  }

  Future<void> unawaitedLoad() async {
    final api = ApiService();
    final remote = await api.ping()
        ? await api.getDashboardScreenings(limit: 20)
        : null;
    List<(String, String, String, String, FigmaStatus)> rows = const [];
    var fromServer = false;
    if (remote != null &&
        remote['items'] is List &&
        (remote['items'] as List).isNotEmpty) {
      fromServer = true;
      rows = (remote['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => (
              (item['patient_id'] ?? '').toString(),
              (item['patient_name'] as String? ?? '').isNotEmpty
                  ? (item['patient_name'] as String)
                  : (item['patient_id'] ?? '').toString(),
              formatScreeningDate(item['created_at'] as String?),
              (item['result_text'] ?? '').toString(),
              liveStatusFor(item['status'] as String?),
            ),
          )
          .toList();
    } else {
      try {
        final password = await OfflineQueueService.resolveDbPassword();
        final store = await LocalStore.open(dbPassword: password);
        try {
          final local = await store.recentScreenings(limit: 40);
          rows = local.map(localScreeningRow).toList();
        } finally {
          await store.close();
        }
      } catch (_) {
        // Storage unavailable: honest empty state, never demo rows.
        rows = const [];
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _rows = rows;
      _fromServer = fromServer;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScannerHUDTheme.background,
      appBar: AppBar(
        backgroundColor: ScannerHUDTheme.darkSurface,
        foregroundColor: ScannerHUDTheme.neonCyan,
        elevation: 0,
        title: Text(
          context.tr('history_title'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.tr('screening_history'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: ScannerHUDTheme.neonCyan,
                    ),
                  ),
                )
              else if (_rows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ScannerHUDTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_off_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'No screening records yet — capture a screening '
                          'for a patient and it appears here.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._rows.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ScannerHUDTheme.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: e.$5.fg,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${e.$4} · ${e.$3}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(status: e.$5),
                      ],
                    ),
                  ),
                ),
              if (!_loading && _rows.isNotEmpty && !_fromServer)
                const SizedBox(height: 8),
              if (!_loading && _rows.isNotEmpty && !_fromServer)
                const Text(
                  'On-device records · sync pending',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
