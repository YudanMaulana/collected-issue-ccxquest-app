import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'repositories/local_issue_repository.dart';
import 'repositories/issue_repository.dart';
import 'screens/pin_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/issue_list_screen.dart';

import 'repositories/supabase_issue_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================
  // TO SWITCH TO SUPABASE BACKEND:
  // 1. Uncomment the block below and replace with your Supabase credentials:
  //
  await Supabase.initialize(
    url: 'https://qttbmizkcmqclzzmqiyd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0dGJtaXprY21xY2x6em1xaXlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk4Njk5NjQsImV4cCI6MjA5NTQ0NTk2NH0.JYdKpuJJaoUhpYwo1qkbKr8s_Urfcj0Ezl35tEP_o24',
  );
  //
  // 2. Change the repository instantiation below to:
  final IssueRepository repository = SupabaseIssueRepository();
  // ==========================================

  // Use SQLite local repository for initial robust operation
  // final IssueRepository repository = LocalIssueRepository();

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
