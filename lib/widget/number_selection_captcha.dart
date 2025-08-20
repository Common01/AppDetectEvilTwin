import 'dart:math';
import 'package:flutter/material.dart';

class NumberSelectionCaptcha extends StatefulWidget {
  final VoidCallback onConfirm;

  const NumberSelectionCaptcha({Key? key, required this.onConfirm}) : super(key: key);

  @override
  State<NumberSelectionCaptcha> createState() => _NumberSelectionCaptchaState();
}

class _NumberSelectionCaptchaState extends State<NumberSelectionCaptcha> with SingleTickerProviderStateMixin {
  late List<int> _numbers;
  late int _correctAnswer;
  String? _feedbackMessage;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _generateNumbers();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _generateNumbers() {
    final random = Random();
    final Set<int> generated = {};

    while (generated.length < 6) {
      final num = random.nextInt(90) + 10; // 2-digit numbers
      generated.add(num);
    }

    _numbers = generated.toList();
    _correctAnswer = _numbers[random.nextInt(_numbers.length)];

    setState(() {
      _feedbackMessage = null;
    });
  }

  void _checkAnswer(int selected) {
    if (selected == _correctAnswer) {
      widget.onConfirm();
    } else {
      setState(() {
        _feedbackMessage = "เลขไม่ถูกต้อง กรุณาลองใหม่";
      });
      _shakeController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 700), () {
        _generateNumbers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ยืนยันตัวตน: โปรดเลือกหมายเลขที่ถูกต้อง',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'เลือกหมายเลข: $_correctAnswer',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _numbers.map((number) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _checkAnswer(number),
              child: Text('$number', style: const TextStyle(fontSize: 18)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_feedbackMessage != null)
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.05)
                .animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn)),
            child: Text(
              _feedbackMessage!,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}
