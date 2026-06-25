import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../services/group_chat_service.dart';
import '../crypto/key_store.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _searchResults = [];
  final Set<String> _selectedMemberIds = {};
  final Map<String, String> _selectedMemberNames = {};
  bool _isSearching = false;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _errorMessage = 'Please enter at least 2 characters';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final token = await KeyStore.getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final users = await ApiService.searchUsers(token, query);
      
      // Filter out already selected users
      final filtered = users.where(
        (u) => !_selectedMemberIds.contains(u.userId)
      ).toList();

      setState(() {
        _searchResults = filtered.map((u) => {
          'userId': u.userId,
          'username': u.username,
          'online': u.online,
        }).toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _addMember(String userId, String username) {
    setState(() {
      _selectedMemberIds.add(userId);
      _selectedMemberNames[userId] = username;
      _searchResults.removeWhere((u) => u['userId'] == userId);
      _errorMessage = null;
    });
  }

  void _removeMember(String userId) {
    setState(() {
      _selectedMemberIds.remove(userId);
      _selectedMemberNames.remove(userId);
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMemberIds.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one member';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final group = await GroupChatService.createGroup(
        name: _nameController.text.trim(),
        memberIds: _selectedMemberIds.toList(),
      );

      if (mounted) {
        Navigator.pop(context, group);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "${group.name}" created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create group: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Group Name
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Group Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter group name',
                          prefixIcon: Icon(Icons.group),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Group name is required';
                          }
                          if (value.trim().length < 3) {
                            return 'Name must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Search Members
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Members',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search by username',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _searchUsers(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isSearching ? null : _searchUsers,
                            child: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Search'),
                          ),
                        ],
                      ),
                      
                      // Search Results
                      if (_searchResults.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Search Results:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        ..._searchResults.map((user) => ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.getAvatarColor(user['username']),
                            child: Text(
                              user['username'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(user['username']),
                          subtitle: user['online'] == true
                              ? const Text('Online', style: TextStyle(color: Colors.green))
                              : const Text('Offline'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.green),
                            onPressed: () => _addMember(
                              user['userId'],
                              user['username'],
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Selected Members
              if (_selectedMemberIds.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Members (${_selectedMemberIds.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedMemberIds.map((userId) {
                            final name = _selectedMemberNames[userId] ?? 'Unknown';
                            return Chip(
                              avatar: CircleAvatar(
                                backgroundColor: AppTheme.getAvatarColor(name),
                                child: Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              label: Text(name),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _removeMember(userId),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Create Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Group',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
