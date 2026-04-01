import 'package:flutter/material.dart';

class PetMoodIndicator extends StatefulWidget {
  final int unreadMessages;

  const PetMoodIndicator({
    Key? key,
    required this.unreadMessages,
  }) : super(key: key);

  @override
  _PetMoodIndicatorState createState() => _PetMoodIndicatorState();
}

class _PetMoodIndicatorState extends State<PetMoodIndicator> {
  String _mood = "happy";

  @override
  void didUpdateWidget(covariant PetMoodIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadMessages > 10) {
      setState(() {
        _mood = "overwhelmed";
      });
    } else if (widget.unreadMessages > 0) {
      setState(() {
        _mood = "curious";
      });
    } else {
      setState(() {
        _mood = "happy";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "Mascot Mood: $_mood",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Icon(
          _mood == "happy"
              ? Icons.sentiment_satisfied
              : _mood == "curious"
                  ? Icons.sentiment_neutral
                  : Icons.sentiment_dissatisfied,
          size: 48,
          color: _mood == "happy"
              ? Colors.green
              : _mood == "curious"
                  ? Colors.orange
                  : Colors.red,
        ),
      ],
    );
  }
}