import 'package:flutter/material.dart';
import '../services/mesh_service.dart';
import 'home_screen.dart';
import 'nearby_screen.dart';
import 'friends_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _totalUnread = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    NearbyScreen(),
    FriendsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    MeshService().messageStream.listen((packet) {
      if (packet.targetId == MeshService().deviceId &&
          packet.senderId != MeshService().deviceId) {
        if (mounted) {
          setState(() => _totalUnread++);
        }
      }
    });
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      setState(() => _totalUnread = 0);
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141928),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: const Color(0xFF141928),
          selectedItemColor: const Color(0xFF00FF88),
          unselectedItemColor: Colors.white24,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'HOME',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'NEARBY',
            ),
            BottomNavigationBarItem(
              icon: _totalUnread > 0
                  ? Badge(
                      label: Text('$_totalUnread'),
                      child: const Icon(Icons.person_outline),
                    )
                  : const Icon(Icons.person_outline),
              activeIcon: _totalUnread > 0
                  ? Badge(
                      label: Text('$_totalUnread'),
                      child: const Icon(Icons.person),
                    )
                  : const Icon(Icons.person),
              label: 'FRIENDS',
            ),
          ],
        ),
      ),
    );
  }
}