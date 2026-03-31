import 'package:flutter/material.dart';
import '../widgets/pet_mood_indicator.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _unreadMessages = 0;

  void _incrementUnreadMessages() {
    setState(() {
      _unreadMessages++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Screen'),
      ),
      body: Column(
        children: [
          PetMoodIndicator(unreadMessages: _unreadMessages),
          ElevatedButton(
            onPressed: _incrementUnreadMessages,
            child: Text('Simulate Unread Message'),
          ),
        ],
      ),
    );
  }
}