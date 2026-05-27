import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'repositories/local_issue_repository.dart';
import 'repositories/issue_repository.dart';
import 'screens/pin_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/issue_list_screen.dart';

import 'repositories/http_issue_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================
  // SERVER DATABASE & STORAGE MANDIRI (SQLite + Express.js)
  // Alamat URL Wifi lokal laptop Anda (Port 5001)
  // ==========================================
  final IssueRepository repository = HttpIssueRepository(
    baseUrl: 'https://cody-chronographic-tobi.ngrok-free.dev/api',
  );

  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  final IssueRepository repository;
  const MyApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collected Issue App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainAuthGateway(repository: repository),
    );
  }
}

class MainAuthGateway extends StatefulWidget {
  final IssueRepository repository;
  const MainAuthGateway({Key? key, required this.repository}) : super(key: key);

  @override
  State<MainAuthGateway> createState() => _MainAuthGatewayState();
}

class _MainAuthGatewayState extends State<MainAuthGateway> {
  bool _unlocked = false;
  int _currentIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(repository: widget.repository),
      IssueListScreen(repository: widget.repository),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return PinScreen(
        onUnlocked: () {
          setState(() {
            _unlocked = true;
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'DASHBOARD' : 'ISSUES RECORD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_open, color: AppTheme.accentYellow),
            onPressed: () {
              // Quick Lock
              setState(() {
                _unlocked = false;
                _currentIndex = 0;
              });
            },
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.borderNavy, width: 1.5),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppTheme.cardBg,
          selectedItemColor: AppTheme.accentYellow,
          unselectedItemColor: AppTheme.textSecondary,
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          iconSize: 22,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard, color: AppTheme.accentYellow),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt, color: AppTheme.accentYellow),
              label: 'Issues',
            ),
          ],
        ),
      ),
    );
  }
}
