import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import '../services/mesh_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    MeshService().updateName(name);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Spacer(),

              // ── Logo ─────────────────────────────────────────────
              const Text(
                'CROWD',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00FF88),
                  letterSpacing: 8,
                  height: 1,
                ),
              ),
              const Text(
                'LINK',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 8,
                  height: 1,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Offline mesh communication.\nNo internet. No servers. Just people.',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),

              const Spacer(),

              // ── Name Input ────────────────────────────────────────
              const Text(
                'WHAT SHOULD WE CALL YOU?',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 20,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your name...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 18,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF141928),
                  counterStyle: TextStyle(color: Colors.white24),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00FF88),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
                onSubmitted: (_) => _saveName(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Continue Button ───────────────────────────────────
              GestureDetector(
                onTap: _isLoading ? null : _saveName,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? const Color(0xFF00FF88).withOpacity(0.3)
                        : const Color(0xFF00FF88),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'JOIN THE MESH',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),

              const Spacer(),

              // ── Footer ────────────────────────────────────────────
              Center(
                child: Text(
                  'Your name is stored only on this device.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 11,
                  ),
                ),
              ),

              const SizedBox(height: 8),

            ],
          ),
        ),
      ),
    );
  }
}