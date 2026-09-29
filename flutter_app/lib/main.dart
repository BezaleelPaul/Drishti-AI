import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/lang_scope.dart';
import 'screens/figma_dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/db/local_store.dart';
import 'services/offline_queue_service.dart';
import 'services/referral_uplink_service.dart';
import 'theme/figma_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ticket B-2: open the durable offline queue (SQLCipher, key in Keystore)
  // and rehydrate the in-memory mirrors. On any failure the queue degrades
  // to memory-only with an honest isPersisted=false flag — the app never
  // crashes at boot over storage.
  unawaited(_initOfflinePersistence());
  runApp(NetraAiApp(langController: LangController()));
}

Future<void> _initOfflinePersistence() async {
  try {
    await OfflineQueueService.init();
    await ApiService.restoreQueues();
    // Ticket D-2: connectivity window at boot — flush consented de-identified
    // referrals that were store-and-forwarded during field camps. Best
    // effort: failures keep them queued for the next window.
    final uplink = await ReferralUplinkService.create();
    await uplink.flushQueued();
  } catch (_) {
    // Boot proceeds with the in-memory queue (loss on restart is possible,
    // but screening never depends on it).
  }
  // Ticket C-5: purge ACKED local screenings past the retention window
  // (90 days, mirroring the server recommendation). Unsynced data is never
  // purged. Best effort — storage failure never blocks the app.
  try {
    final password = await OfflineQueueService.resolveDbPassword();
    final store = await LocalStore.open(dbPassword: password);
    await store.purgeExpiredData(retentionDays: 90);
    await store.close();
  } catch (_) {
    // Purge is maintenance, not a boot dependency.
  }
}

class NetraAiApp extends StatelessWidget {
  final LangController langController;

  const NetraAiApp({super.key, required this.langController});

  @override
  Widget build(BuildContext context) {
    return LangScope(
      notifier: langController,
      child: MaterialApp(
        title: 'Netra-AI Rural Health Screening',
        debugShowCheckedModeBanner: false,
        theme: buildFigmaTheme(),
        home: const FigmaDashboardScreen(),
      ),
    );
  }
}
