import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/mesh_service.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MeshService().init();
  await NotificationService().init();
  runApp(const CrowdLinkApp());
}

class CrowdLinkApp extends StatelessWidget {
  const CrowdLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrowdLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF88),
          secondary: Color(0xFF0088FF),
          surface: Color(0xFF141928),
        ),
      ),
      home: const SplashRouter(),
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => name != null && name.isNotEmpty
              ? const MainScreen()
              : const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00FF88),
        ),
      ),
    );
  }
}