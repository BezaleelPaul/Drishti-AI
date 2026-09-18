import 'package:flutter/material.dart';
import '../l10n/lang_scope.dart';
import '../theme/figma_theme.dart';
import '../widgets/figma_drawer.dart';
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
class FigmaDashboardScreen extends StatelessWidget {
  const FigmaDashboardScreen({super.key});

  static const _recent = [
    (
      'PHC-2026-1024',
      'Meena Devi',
      '11 Sep 2026',
      'Moderate NPDR',
      FigmaStatus.verified,
    ),
    (
      'PHC-2026-1023',
      'Rajan Kumar',
      '11 Sep 2026',
      'Severe NPDR',
      FigmaStatus.referral,
    ),
    (
      'PHC-2026-1022',
      'Sunita Bai',
      '10 Sep 2026',
      'Mild NPDR',
      FigmaStatus.awaitingSpecialist,
    ),
    (
      'PHC-2026-1021',
      'Ashok Singh',
      '10 Sep 2026',
      'No DR',
      FigmaStatus.verified,
    ),
    (
      'PHC-2026-1020',
      'Kamla Yadav',
      '09 Sep 2026',
      'Pending',
      FigmaStatus.offline,
    ),
  ];

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
    return Scaffold(
      backgroundColor: FigmaColors.surface,
      drawer: const FigmaDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: FigmaColors.primaryDark,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.remove_red_eye_outlined, color: FigmaColors.primaryDark),
            SizedBox(width: 6),
            Text(
              'Drishti-AI',
              style: TextStyle(
                color: FigmaColors.primaryDark,
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
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: FigmaColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  context.tr('online'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.success,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<AppLang>(
            icon: const Icon(
              Icons.language,
              color: FigmaColors.primaryDark,
              size: 20,
            ),
            tooltip: 'Language',
            onSelected: (lang) => LangScope.setLang(context, lang),
            itemBuilder: (_) => AppLang.values
                .map(
                  (l) => PopupMenuItem(
                    value: l,
                    child: Text(
                      l.displayName,
                      style: TextStyle(
                        fontWeight: LangScope.langOf(context) == l
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: LangScope.langOf(context) == l
                            ? FigmaColors.primaryDark
                            : FigmaColors.text,
                      ),
                    ),
                  ),
                )
                .toList(),
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
                          '8',
                          FigmaColors.primaryDark,
                          FigmaColors.primarySoft,
                          FigmaColors.primaryBorder,
                        ),
                        _statCard(
                          context,
                          'awaiting_ai',
                          '2',
                          const Color(0xFFB45309),
                          const Color(0xFFFFFBEB),
                          const Color(0xFFFDE68C),
                        ),
                        _statCard(
                          context,
                          'awaiting_specialist',
                          '3',
                          FigmaColors.purple,
                          const Color(0xFFFAF5FF),
                          const Color(0xFFE9D5FF),
                        ),
                        _statCard(
                          context,
                          'urgent_referrals',
                          '1',
                          const Color(0xFFB91C1C),
                          const Color(0xFFFEF2F2),
                          const Color(0xFFFECACA),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Offline banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FigmaColors.border),
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
                                  '1 ${context.tr('case_waiting')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: FigmaColors.text,
                                  ),
                                ),
                                Text(
                                  context.tr('captured_offline'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: FigmaColors.muted,
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
                                color: FigmaColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('recent_screenings'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: FigmaColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (wide)
                      _recentTable(context)
                    else
                      ..._recent.map(
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
        Text(
          context.tr('dash_title'),
          textAlign: TextAlign.start,
          softWrap: true,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: FigmaColors.text,
          ),
        ),
        Text(
          context.tr('dash_subtitle'),
          style: const TextStyle(fontSize: 13, color: FigmaColors.muted),
        ),
        Text(
          context.tr('demo_data'),
          style: const TextStyle(fontSize: 11, color: FigmaColors.faint),
        ),
      ],
    );
  }

  Widget _startButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: FigmaColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _startScreening(context),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          context.tr('start_screening'),
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
              color: Color(0xFF475569),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FigmaColors.border),
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
                      color: FigmaColors.text,
                    ),
                  ),
                  Text(
                    s.$1,
                    style: const TextStyle(
                      fontSize: 11,
                      color: FigmaColors.faint,
                    ),
                  ),
                  Text(
                    '${s.$4} · ${s.$3}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: FigmaColors.muted,
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

  Widget _recentTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: FigmaColors.border)),
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
          ..._recent.map(
            (s) => InkWell(
              onTap: () => _openHistory(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
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
                              color: FigmaColors.text,
                            ),
                          ),
                          Text(
                            s.$1,
                            style: const TextStyle(
                              fontSize: 11,
                              color: FigmaColors.faint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s.$3,
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s.$4,
                        style: const TextStyle(color: FigmaColors.text),
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
        color: Color(0xFF475569),
      ),
    );
  }
}
