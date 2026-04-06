import 'dart:async';
import 'package:flutter/material.dart';

/// Shows a live countdown timer on each chat bubble.
/// When it reaches zero the parent (ChatScreen) removes the message.
class DisappearingTimer extends StatefulWidget {
  final DateTime expiresAt;
  const DisappearingTimer({super.key, required this.expiresAt});

  @override
  State<DisappearingTimer> createState() => _DisappearingTimerState();
}

class _DisappearingTimerState extends State<DisappearingTimer> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _calcRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _remaining = _calcRemaining());
      }
    });
  }

  Duration _calcRemaining() {
    final r = widget.expiresAt.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = _remaining.inSeconds;

    // Colour shifts: green → orange → red as time runs out
    final color = secs > 20
        ? Colors.white70
        : secs > 10
            ? Colors.amber.shade200
            : Colors.red.shade200;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, color: color, size: 11),
        const SizedBox(width: 3),
        Text(
          '${secs}s',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
