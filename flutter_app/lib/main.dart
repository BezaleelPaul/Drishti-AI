import 'package:flutter/material.dart';
import 'screens/district_simulation_screen.dart';
import 'screens/doctor_review_screen.dart';
import 'screens/integrated_screening_flow.dart';
import 'screens/system_specs_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const NetraAiApp());
}

class NetraAiApp extends StatelessWidget {
  const NetraAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netra-AI Rural Health Screening',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF0D9488),
          surface: const Color(0xFFF8FAFC),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 1,
        ),
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    final screens = [
      IntegratedScreeningFlow(apiService: _apiService),
      DoctorReviewScreen(apiService: _apiService),
      const DistrictSimulationScreen(),
      const SystemSpecsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: const Color(0xFF1E3A8A),
                unselectedItemColor: const Color(0xFF64748B),
                backgroundColor: Colors.white,
                elevation: 0,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                onTap: (index) => setState(() => _currentIndex = index),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.remove_red_eye_rounded),
                    activeIcon: Icon(Icons.remove_red_eye, color: Color(0xFF1E3A8A)),
                    label: 'ASHA Pipeline',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.medical_services_outlined),
                    activeIcon: Icon(Icons.medical_services, color: Color(0xFF1E3A8A)),
                    label: 'Doctor Review',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.hub_outlined),
                    activeIcon: Icon(Icons.hub_rounded, color: Color(0xFF1E3A8A)),
                    label: 'District Sim (100k)',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.tune_outlined),
                    activeIcon: Icon(Icons.tune_rounded, color: Color(0xFF1E3A8A)),
                    label: 'System & Cameras',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
