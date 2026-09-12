import 'package:flutter/material.dart';
import '../l10n/lang_scope.dart';
import '../services/api_service.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final ApiService _apiService = ApiService();
  bool _isSyncing = false;
  String? _syncMessage;
  bool _syncFailed = false;

  Future<void> _handleSync() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
      _syncFailed = false;
    });

    final res = await _apiService.syncOfflineBatch();
    if (!mounted) return;
    final err = res['error']?.toString();
    final synced = (res['total_synced'] as num?)?.toInt() ?? 0;
    final received = (res['total_received'] as num?)?.toInt() ?? 0;
    final failed = res['failed_items'] is List
        ? (res['failed_items'] as List).length
        : 0;
    final failedPatients = res['failed_patients'] is List
        ? (res['failed_patients'] as List).length
        : 0;
    final dropped = (res['dropped_corrupt'] as num?)?.toInt() ?? 0;
    setState(() {
      _isSyncing = false;
      if (err != null) {
        _syncFailed = true;
        _syncMessage = 'Sync failed: $err';
      } else if (synced > 0) {
        _syncFailed = failed > 0 || failedPatients > 0;
        _syncMessage =
            'Synchronized $synced of $received record(s) with District Hospital.'
            '${failed > 0 ? ' $failed item(s) rejected — kept in queue.' : ''}'
            '${failedPatients > 0 ? ' $failedPatients patient(s) failed registration.' : ''}'
            '${dropped > 0 ? ' $dropped corrupt entr(y/ies) discarded.' : ''}';
      } else {
        _syncFailed = failed > 0 || failedPatients > 0;
        _syncMessage =
            (res['message'] ??
                    'Nothing uploaded. ${failed > 0 ? "$failed item(s) rejected — kept in queue." : "Check connectivity and retry."}')
                .toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = ApiService.offlineQueue;
    final pendingPatients = ApiService.offlinePatients.length;
    final hasPending = queue.isNotEmpty || pendingPatients > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('offline_title'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: !hasPending
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !hasPending
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      !hasPending ? Icons.cloud_done : Icons.cloud_queue,
                      color: !hasPending
                          ? Colors.green
                          : Colors.orange.shade800,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !hasPending
                                ? context.tr('sync_complete')
                                : '${queue.length} ${context.tr('cases_waiting')}${pendingPatients > 0 ? ' + $pendingPatients' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !hasPending
                                  ? Colors.green.shade800
                                  : Colors.orange.shade900,
                            ),
                          ),
                          Text(
                            !hasPending
                                ? context.tr('sync1')
                                : context.tr('offline_subtitle'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_syncMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _syncFailed
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _syncFailed
                          ? Colors.red.shade300
                          : Colors.blue.shade300,
                    ),
                  ),
                  child: Text(
                    _syncMessage!,
                    style: TextStyle(
                      color: _syncFailed
                          ? Colors.red.shade900
                          : const Color(0xFF1A56DB),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Queue List
              Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.check_circle_outline,
                              size: 60,
                              color: Colors.green,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Queue is Empty',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'All rural field scans have been safely stored.',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final item = queue[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF1A56DB),
                                child: Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                '${item['patient_id']} • ${item['eye_side']} Eye',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                "Preset: ${item['camera_profile']}\nCaptured: ${item['timestamp'] ?? item['captured_at'] ?? '-'}",
                                style: const TextStyle(fontSize: 11),
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),

              // Sync Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  _isSyncing ? context.tr('syncing') : context.tr('btn_sync'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isSyncing || !hasPending ? null : _handleSync,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
