import 'package:flutter/material.dart';
import 'dart:async';
import '../core/theme.dart';

class PinScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinScreen({Key? key, required this.onUnlocked}) : super(key: key);

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  final String _correctPin = '1999';
  bool _hasError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 24.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _hasError = false;
    });

    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _hasError = false;
    });
  }

  void _verifyPin() {
    if (_pin == _correctPin) {
      widget.onUnlocked();
    } else {
      setState(() {
        _hasError = true;
      });
      _shakeController.forward(from: 0.0).then((_) {
        setState(() {
          _pin = '';
          _hasError = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.primaryNavy],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Premium Logo / Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNavy,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentYellow, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentYellow.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppTheme.accentYellow,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'COLLECTED ISSUE',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter PIN to Access Database',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const Spacer(),

              // PIN Indicators
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * (1.0 - (_shakeController.value * 2 - 1).abs()), 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        bool active = index < _pin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _hasError
                                ? Colors.redAccent
                                : active
                                    ? AppTheme.accentYellow
                                    : Colors.transparent,
                            border: Border.all(
                              color: _hasError
                                  ? Colors.redAccent
                                  : active
                                      ? AppTheme.accentYellow
                                      : AppTheme.borderNavy,
                              width: 2,
                            ),
                            boxShadow: active && !_hasError
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accentYellow.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),

              // Keypad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _buildRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 70, height: 70), // Empty spacer
                        _buildKeypadButton('0'),
                        _buildBackspaceButton(),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return GestureDetector(
      onTap: () => _onKeyPress(digit),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: AppTheme.secondaryNavy.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.borderNavy, width: 1.5),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: AppTheme.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}
