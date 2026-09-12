import 'package:flutter/material.dart';
import '../l10n/lang_scope.dart';
import '../services/api_service.dart';
import '../screens/checkin_screen.dart';
import '../screens/district_simulation_screen.dart';
import '../screens/doctor_review_screen.dart';
import '../screens/figma_dashboard_screen.dart';
import '../screens/figma_help_screen.dart';
import '../screens/figma_history_screen.dart';
import '../screens/integrated_screening_flow.dart';
import '../screens/queue_screen.dart';
import '../screens/system_specs_screen.dart';
import '../theme/figma_theme.dart';

/// Figma sidebar/drawer: primary nav (dashboard/history/offline/help)
/// plus the backend-wired clinical screens so none are orphaned.
class FigmaDrawer extends StatelessWidget {
  const FigmaDrawer({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    color: FigmaColors.primaryDark,
                  ),
                  SizedBox(width: 8),
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
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  _item(
                    context,
                    '🏠',
                    'nav_dashboard',
                    const FigmaDashboardScreen(),
                    true,
                  ),
                  _item(
                    context,
                    '📋',
                    'nav_history',
                    const FigmaHistoryScreen(),
                    false,
                  ),
                  _item(
                    context,
                    '📡',
                    'nav_offline',
                    const QueueScreen(),
                    false,
                  ),
                  _item(
                    context,
                    '❓',
                    'nav_help',
                    const FigmaHelpScreen(),
                    false,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Text(
                      'Clinical',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.faint,
                      ),
                    ),
                  ),
                  _rawItem(
                    context,
                    Icons.medical_services_outlined,
                    'Specialist Review Queue',
                    DoctorReviewScreen(apiService: api),
                  ),
                  _rawItem(
                    context,
                    Icons.view_carousel_outlined,
                    'Integrated 3-Step Flow',
                    IntegratedScreeningFlow(apiService: api),
                  ),
                  _rawItem(
                    context,
                    Icons.person_add_outlined,
                    'Classic Check-In',
                    const CheckInScreen(),
                  ),
                  _rawItem(
                    context,
                    Icons.map_outlined,
                    'District Simulation',
                    const DistrictSimulationScreen(),
                  ),
                  _rawItem(
                    context,
                    Icons.settings_outlined,
                    'System Specs',
                    const SystemSpecsScreen(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
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
                  const SizedBox(width: 6),
                  Text(
                    context.tr('online'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FigmaColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String emoji,
    String labelKey,
    Widget page,
    bool selected,
  ) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: selected ? FigmaColors.primarySoft : null,
      leading: Text(emoji, style: const TextStyle(fontSize: 18)),
      title: Text(
        context.tr(labelKey),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: selected ? FigmaColors.primaryDark : FigmaColors.text,
        ),
      ),
      onTap: () => _go(context, page),
    );
  }

  Widget _rawItem(
    BuildContext context,
    IconData icon,
    String label,
    Widget page,
  ) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, size: 20, color: FigmaColors.muted),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, color: FigmaColors.text),
      ),
      onTap: () => _go(context, page),
    );
  }
}
