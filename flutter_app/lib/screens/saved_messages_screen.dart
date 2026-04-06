import 'package:flutter/material.dart';

class SavedMessagesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Messages'),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Messages'),
          _buildSavedItemList(['Message 1', 'Message 2', 'Message 3']),
          _buildSectionHeader('Media'),
          _buildSavedItemList(['Image 1', 'Video 1']),
          _buildSectionHeader('Files'),
          _buildSavedItemList(['File 1', 'File 2']),
          _buildSectionHeader('Reminders'),
          _buildSavedItemList(['Reminder 1', 'Reminder 2']),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSavedItemList(List<String> items) {
    return Column(
      children: items.map((item) => ListTile(
        title: Text(item),
        leading: Icon(Icons.bookmark),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {},
      )).toList(),
    );
  }
}