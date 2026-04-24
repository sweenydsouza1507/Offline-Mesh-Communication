import 'package:flutter/material.dart';
import 'services/mesh_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MeshService().init();
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
      home: const HomeScreen(),
    );
  }
}