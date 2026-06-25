import 'dart:async';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';

/// A small badge showing the current socket connection status.
/// Turns green when connected, red when disconnected, yellow when reconnecting.
class ConnectionIndicator extends StatefulWidget {
  const ConnectionIndicator({super.key});

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator> {
  bool _connected = SocketService.isConnected;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SocketService.connectionStream.listen((connected) {
      if (mounted) setState(() => _connected = connected);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _connected;
    return Tooltip(
      message: connected ? 'Connected' : 'Disconnected',
      child: Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: connected ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
          boxShadow: [
            BoxShadow(
              color: (connected ? const Color(0xFF4CAF50) : const Color(0xFFE57373)).withValues(alpha: 0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
