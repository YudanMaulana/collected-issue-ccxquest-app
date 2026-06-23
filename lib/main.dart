import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'core/theme.dart';
import 'repositories/issue_repository.dart';
import 'screens/pin_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/issue_list_screen.dart';
import 'screens/incomplete_issues_screen.dart';

import 'repositories/http_issue_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================
  // SERVER DATABASE & STORAGE MANDIRI (SQLite + Express.js)
  // Alamat URL Wifi lokal laptop Anda (Port 5001)
  // ==========================================
  final IssueRepository repository = HttpIssueRepository(
    baseUrl: 'https://server.choclatosxquest.web.id/api',
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
  bool? _apiConnected;
  Timer? _apiCheckTimer;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(repository: widget.repository),
      IssueListScreen(repository: widget.repository),
      IncompleteIssuesScreen(repository: widget.repository),
    ];
    _checkApiConnection();
    _apiCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkApiConnection();
    });
  }

  @override
  void dispose() {
    _apiCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkApiConnection() async {
    try {
      String? url;
      if (widget.repository is HttpIssueRepository) {
        url = (widget.repository as HttpIssueRepository).baseUrl;
      }
      if (url != null) {
        final uri = Uri.parse('$url/health');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          if (mounted && _apiConnected != true) {
            setState(() {
              _apiConnected = true;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted && _apiConnected != false) {
      setState(() {
        _apiConnected = false;
      });
    }
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
        title: Text(
          _currentIndex == 0
              ? 'DASHBOARD'
              : _currentIndex == 1
                  ? 'ISSUES RECORD'
                  : 'INCOMPLETE DATA',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Tooltip(
                message: _apiConnected == null
                    ? 'Checking API connection...'
                    : _apiConnected == true
                        ? 'API Connected'
                        : 'API Disconnected',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _apiConnected == null
                            ? Colors.grey
                            : _apiConnected == true
                                ? Colors.greenAccent.shade400
                                : Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_apiConnected == true)
                            BoxShadow(
                              color: Colors.greenAccent.shade400.withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          if (_apiConnected == false)
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _apiConnected == null
                          ? 'Checking...'
                          : _apiConnected == true
                              ? 'ONLINE'
                              : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _apiConnected == null
                            ? Colors.grey
                            : _apiConnected == true
                                ? Colors.greenAccent.shade400
                                : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_late_outlined),
              activeIcon: Icon(Icons.assignment_late, color: AppTheme.accentYellow),
              label: 'Incomplete',
            ),
          ],
        ),
      ),
    );
  }
}
