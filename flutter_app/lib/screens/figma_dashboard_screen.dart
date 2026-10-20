import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/lang_scope.dart';
import '../services/api_service.dart';
import '../services/db/local_store.dart';
import '../services/ml/pipeline_schema.dart';
import '../services/offline_queue_service.dart';
import '../theme/figma_theme.dart';
import '../widgets/charts/severity_distribution_chart.dart';
import '../widgets/futuristic/futuristic_ui.dart';
import '../widgets/nav/neon_nav_rail.dart';
import '../widgets/orbit/orbit.dart';
import '../widgets/scanner/scanner_theme.dart';
import '../widgets/status_badge.dart';
import 'flow/flow_register_screen.dart';
import 'figma_history_screen.dart';
import 'queue_screen.dart';

/// Figma "PHC Dashboard" ported to Flutter.
///
/// Layout mirrors the prototype: title block + start button, four stat
/// cards (cyan/amber/purple/red), offline banner, recent screenings
/// (cards on narrow, table rows on wide). All strings localized (en/kn/hi/te/ta).
/// Navigation targets are the existing backend-wired screens.
///
/// Ticket B-3: the Online/Offline badge is LIVE (server ping every 30 s)
/// and shows the durable queue depth — the dashboard never claims
/// connectivity it does not have (the old badge was hardcoded green).
class FigmaDashboardScreen extends StatefulWidget {
  const FigmaDashboardScreen({super.key});

  @override
  State<FigmaDashboardScreen> createState() => _FigmaDashboardScreenState();
}

class _FigmaDashboardScreenState extends State<FigmaDashboardScreen> {
  final _api = ApiService();
  bool? _online; // null = unknown (probing)
  int _queuedCount = 0;
  int _queuedAi = 0;
  Map<String, dynamic>? _live;
  List<Map<String, Object?>> _localRows = const [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final online = await _api.ping();
    final persisted = await OfflineQueueService.instance.restoreAll();
    final deid = await OfflineQueueService.instance.restoreKind(
      OfflineQueueService.kindDeidReferral,
    );
    final live = online ? await _api.getDashboardScreenings() : null;
    // Offline fallback feed: the REAL screenings recorded on this device via
    // LocalStore — never fabricated patient rows. Loaded only when the server
    // feed is unavailable or empty so device data can never mask live data.
    List<Map<String, Object?>> localRows = const [];
    if (!_liveReadyOf(live)) {
      localRows = await _loadLocalScreenings(limit: 6);
    }
    if (!mounted) return;
    setState(() {
      _online = online;
      _queuedCount =
          persisted.screenings.length + persisted.patients.length + deid.length;
      _queuedAi = persisted.screenings.length;
      _live = live;
      _localRows = localRows;
    });
  }

  Future<List<Map<String, Object?>>> _loadLocalScreenings({
    required int limit,
  }) async {
    try {
      final password = await OfflineQueueService.resolveDbPassword();
      final store = await LocalStore.open(dbPassword: password);
      try {
        return await store.recentScreenings(limit: limit);
      } finally {
        await store.close();
      }
    } catch (_) {
      // Storage unavailable (first run, locked DB): an empty honest feed —
      // never demo rows in its place.
      return const [];
    }
  }

  bool get _liveReady => _liveReadyOf(_live);

  bool _liveReadyOf(dynamic live) {
    final items = live is Map<String, dynamic> ? live['items'] : null;
    return items is List && items.isNotEmpty;
  }

  List<(String, String, String, String, FigmaStatus)> get _rows {
    final items = _live?['items'];
    if (_liveReady && items is List) {
      return items.whereType<Map<String, dynamic>>().map(_liveRow).toList();
    }
    return _localRows.map(localScreeningRow).toList();
  }

  (String, String, String, String, FigmaStatus) _liveRow(
    Map<String, dynamic> item,
  ) {
    final name = item['patient_name'];
    final hasName = name is String && name.isNotEmpty;
    final pid = (item['patient_id'] ?? '').toString();
    final result = (item['result_text'] ?? '').toString();
    final status = liveStatusFor(item['status'] as String?);
    return (
      hasName ? pid : '',
      hasName ? name : pid,
      formatScreeningDate(item['created_at'] as String?),
      result,
      status,
    );
  }

  // ---- Real local stat fallbacks (zero when nothing was captured) ----

  int get _localTodayCount {
    final now = DateTime.now();
    return _localRows.where((r) {
      final created = DateTime.tryParse('${r['created_at'] ?? ''}');
      if (created == null) return false;
      final localCreated = created.toLocal();
      return localCreated.year == now.year &&
          localCreated.month == now.month &&
          localCreated.day == now.day;
    }).length;
  }

  int get _localAwaitingReviewCount => _localRows
      .where((r) => ((r['requires_human_review'] as num?)?.toInt() ?? 0) == 1)
      .length;

  int get _localUrgentCount => _localRows
      .where((r) => ((r['dr_grade_num'] as num?)?.toInt() ?? 0) >= 3)
      .length;

  String _tileValue(String key, String Function() localFallback) {
    final stats = _live?['stats'];
    if (stats is Map<String, dynamic> && stats[key] is num) {
      return (stats[key] as num).toString();
    }
    return localFallback();
  }

  void _startScreening(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FlowRegisterScreen()),
    );
  }

  void _openQueue(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QueueScreen()),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FigmaHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = _online;
    final badgeColor = online == null
        ? const Color(0xFF94A3B8)
        : (online ? ScannerHUDTheme.success : ScannerHUDTheme.danger);
    final badgeBg = online == null
        ? const Color(0xFF1E293B)
        : (online ? const Color(0xFF052E16) : const Color(0xFF2A0F0F));
    final badgeText = online == null
        ? '…' // probing — language-neutral; resolves within one ping
        : (online ? context.tr('online') : context.tr('offline'));
    return Scaffold(
      backgroundColor: ScannerHUDTheme.background,
      drawer: NeonNavRail(
        entries: buildNavEntries(context),
        activeLabel: context.tr('nav_dashboard'),
        queuedCount: _queuedCount,
        online: _online,
      ),
      appBar: AppBar(
        backgroundColor: ScannerHUDTheme.darkSurface,
        foregroundColor: ScannerHUDTheme.neonCyan,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.remove_red_eye_outlined,
              color: ScannerHUDTheme.neonCyan,
            ),
            SizedBox(width: 6),
            Text(
              'Drishti-AI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
                if (_queuedCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: FigmaColors.primaryDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_queuedCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<AppLang>(
            icon: const Icon(
              Icons.language,
              color: ScannerHUDTheme.neonCyan,
              size: 20,
            ),
            tooltip: 'Language',
            color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            onSelected: (lang) => LangScope.setLang(context, lang),
            itemBuilder: (_) {
              final active = LangScope.langOf(context);
              return AppLang.values.map((l) {
                final isActive = active == l;
                return PopupMenuItem(
                  value: l,
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: isActive
                            ? ScannerHUDTheme.neonCyan
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.displayName,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? ScannerHUDTheme.neonCyan
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title block + CTA (Figma: row on laptop, stacked on phone)
                    wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: _titleBlock(context)),
                              const SizedBox(width: 12),
                              _startButton(context),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _titleBlock(context),
                              const SizedBox(height: 12),
                              _startButton(context),
                            ],
                          ),
                    const SizedBox(height: 12),
                    // Orbit hero centered under the header; keeps the header
                    // row's baseline layout intact on every width.
                    Center(child: _orbitHero(context)),
                    const SizedBox(height: 4),
                    const SizedBox(height: 16),
                    // Stat cards
                    GridView.count(
                      crossAxisCount: wide ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: wide ? 1.25 : 1.35,
                      children: [
                        _statCard(
                          context,
                          'todays_screenings',
                          _tileValue(
                            'today_screenings',
                            () => '$_localTodayCount',
                          ),
                          ScannerHUDTheme.neonCyan,
                          ScannerHUDTheme.darkSurface,
                          const Color(0xFF1E293B),
                        ),
                        _statCard(
                          context,
                          'awaiting_ai',
                          '$_queuedAi',
                          const Color(0xFFF59E0B),
                          ScannerHUDTheme.darkSurface,
                          const Color(0xFF1E293B),
                        ),
                        _statCard(
                          context,
                          'awaiting_specialist',
                          _tileValue(
                            'awaiting_specialist',
                            () => '$_localAwaitingReviewCount',
                          ),
                          const Color(0xFFA855F7),
                          ScannerHUDTheme.darkSurface,
                          const Color(0xFF1E293B),
                        ),
                        _statCard(
                          context,
                          'urgent_referrals',
                          _tileValue(
                            'urgent_referrals',
                            () => '$_localUrgentCount',
                          ),
                          const Color(0xFFEF4444),
                          ScannerHUDTheme.darkSurface,
                          const Color(0xFF1E293B),
                        ),
                      ],
                    ),
                    if (_queuedCount > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: ScannerHUDTheme.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          children: [
                            const Text('📡', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_queuedCount ${context.tr('case_waiting')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    context.tr('captured_offline'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openQueue(context),
                              child: Text(
                                context.tr('view_arrow'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ScannerHUDTheme.neonCyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SeverityDistributionChart(
                      buckets: buildSeverityBuckets(_rows.map((r) => r.$4)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('recent_screenings'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_rows.isEmpty)
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
                              color: FigmaColors.faint,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'No screenings on this device yet — '
                                'capture one to begin.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (wide)
                      _recentTable(context, _rows)
                    else
                      ..._rows.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _recentCard(context, s),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _titleBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: ScannerHUDTheme.neonCyan.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ScannerHUDTheme.neonCyan,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'RETINAL DIAGNOSTIC HUD // AI V1.2',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ScannerHUDTheme.hudMonoStyle.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.0,
                    color: ScannerHUDTheme.neonCyan,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          context.tr('dash_title'),
          textAlign: TextAlign.start,
          softWrap: true,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        Text(
          context.tr('dash_subtitle'),
          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
        if (_localRows.isNotEmpty && !_liveReady)
          const Text(
            'On-device records · sync pending',
            style: TextStyle(fontSize: 11, color: FigmaColors.faint),
          ),
      ],
    );
  }

  Widget _startButton(BuildContext context) {
    return FuturisticGlowButton(
      label: context.tr('start_screening'),
      glowColor: FigmaColors.primary,
      backgroundColor: FigmaColors.primary,
      onPressed: () => _startScreening(context),
    );
  }

  /// Ambient orbit hero: idle rings plus an honest link-state label derived
  /// from the real ping result (never claims readiness it does not have).
  Widget _orbitHero(BuildContext context) {
    final online = _online;
    return SizedBox(
      width: 220,
      height: 220,
      // The orbit sizes its central slot from ambient screen width; scope the
      // MediaQuery so the embed fits its container instead of the viewport.
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(size: const Size(480, 480)),
        child: OrbitScanner(
          state: OrbitScannerState.idle,
          statusText: online == null
              ? 'PROBING LINK'
              : (online ? 'LINK ONLINE' : 'LINK OFFLINE'),
          technicalLabel: _queuedCount > 0 ? 'queued: $_queuedCount' : null,
        ),
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String labelKey,
    String value,
    Color numberColor,
    Color bg,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 26,
              color: numberColor,
            ),
          ),
          Text(
            context.tr(labelKey),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentCard(
    BuildContext context,
    (String, String, String, String, FigmaStatus) s,
  ) {
    return InkWell(
      onTap: () => _openHistory(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ScannerHUDTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    s.$1,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    '${s.$4} · ${s.$3}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(status: s.$5),
          ],
        ),
      ),
    );
  }

  Widget _recentTable(
    BuildContext context,
    List<(String, String, String, String, FigmaStatus)> rows,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: ScannerHUDTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: _th(context.tr('col_patient'))),
                Expanded(child: _th(context.tr('col_date'))),
                Expanded(child: _th(context.tr('col_ai_result'))),
                Expanded(child: _th(context.tr('col_status'))),
              ],
            ),
          ),
          ...rows.map(
            (s) => InkWell(
              onTap: () => _openHistory(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            s.$1,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s.$3,
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s.$4,
                        style: const TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    Expanded(child: StatusBadge(status: s.$5)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

const _monthAbbrevs = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

FigmaStatus liveStatusFor(String? status) {
  switch (status) {
    case 'referral':
      return FigmaStatus.referral;
    case 'awaiting_specialist':
      return FigmaStatus.awaitingSpecialist;
    case 'rejected':
      return FigmaStatus.rejected;
    case 'awaiting_ai':
      return FigmaStatus.awaitingAi;
    default:
      return FigmaStatus.verified;
  }
}

/// The two quality/domain gate codes that mean "this capture can never be
/// graded locally" — shown as rejected, not as pending.
bool _isRejectionCode(String? code) =>
    code == PipelineErrorCode.imgInvalid.code ||
    code == PipelineErrorCode.imgNotFundus.code ||
    code == PipelineErrorCode.imgUntgradable.code;

/// Result text derived ONLY from what the local row actually contains:
/// the stored DR label (or the grade-derived canonical label) when graded,
/// the gate code when rejected, an honest "pending / unavailable" otherwise.
String localScreeningResult(Map<String, Object?> row) {
  final label = (row['dr_label'] ?? '').toString();
  if (label.isNotEmpty) return label;
  final gradeNum = (row['dr_grade_num'] as num?)?.toInt();
  if (gradeNum != null) {
    final grade = DrGrade.tryFromValue(gradeNum);
    if (grade != null) return grade.label;
  }
  final code = (row['error_code'] ?? '').toString();
  if (_isRejectionCode(code)) return code;
  final review = ((row['requires_human_review'] as num?)?.toInt() ?? 0) == 1;
  return review ? 'Awaiting review' : 'Pending AI';
}

/// Honest badge for a locally stored screening. Sync state is the source of
/// truth for verification — a row on this device is NEVER labelled as
/// server-verified while it is still local-only.
FigmaStatus localScreeningStatus(Map<String, Object?> row) {
  final errorCode = (row['error_code'] ?? '').toString();
  if (_isRejectionCode(errorCode)) return FigmaStatus.rejected;
  final review = ((row['requires_human_review'] as num?)?.toInt() ?? 0) == 1;
  if (review) return FigmaStatus.awaitingSpecialist;
  switch ((row['sync_state'] ?? '').toString()) {
    case 'acked':
    case 'review_received':
      return FigmaStatus.verified;
    case 'syncing':
      return FigmaStatus.awaitingAi;
    default:
      return FigmaStatus.offline;
  }
}

/// Maps a `LocalStore.recentScreenings` row onto the dashboard/history
/// row-tuple so the offline feed renders the same contract as the server feed.
(String, String, String, String, FigmaStatus) localScreeningRow(
  Map<String, Object?> row,
) {
  final name = (row['name'] ?? '').toString();
  final pid = (row['local_patient_id'] ?? '').toString();
  return (
    pid,
    name.isNotEmpty ? name : pid,
    formatScreeningDate((row['created_at'] ?? '').toString()),
    localScreeningResult(row),
    localScreeningStatus(row),
  );
}

String formatScreeningDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
  final day = parsed.day.toString().padLeft(2, '0');
  return '$day ${_monthAbbrevs[parsed.month - 1]} ${parsed.year}';
}
