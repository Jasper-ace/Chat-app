import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/tradie_api_auth_service.dart';
import '../services/chat_api_service.dart';

class SelectUserScreen extends ConsumerStatefulWidget {
  const SelectUserScreen({super.key});

  @override
  ConsumerState<SelectUserScreen> createState() => _SelectUserScreenState();
}

class _SelectUserScreenState extends ConsumerState<SelectUserScreen> {
  final _authService = TradieApiAuthService();
  final _chatService = ChatApiService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Fetch all homeowners from Laravel API
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/homeowners'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _users = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _users = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _users = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _startChat(Map<String, dynamic> homeowner) async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Create chat room
      final chatId = await _chatService.createChatRoom(
        participant1Id: userId.toString(),
        participant1Type: 'tradie',
        participant2Id: homeowner['id'].toString(),
        participant2Type: 'homeowner',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (chatId != null) {
        // Navigate to chat screen
        context.go(
          '/chat/$chatId',
          extra: {
            'otherUserName': homeowner['name'] ?? 'Homeowner',
            'otherUserId': homeowner['id'].toString(),
            'otherUserType': 'homeowner',
          },
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to create chat')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final name = (user['name'] ?? '').toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Select Homeowner', style: AppTextStyles.appBarTitle),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search homeowners...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? _buildEmptyState()
                : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 80,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            _searchQuery.isEmpty ? 'No homeowners found' : 'No results',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            _searchQuery.isEmpty
                ? 'Homeowners will appear here'
                : 'Try a different search',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserItem(user);
      },
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final name = user['name'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final city = user['city'] ?? '';
    final region = user['region'] ?? '';
    final location = [city, region].where((s) => s.isNotEmpty).join(', ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(name, style: AppTextStyles.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(email, style: AppTextStyles.bodySmall),
          if (location.isNotEmpty)
            Text(
              location,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chat_bubble_outline),
      onTap: () => _startChat(user),
    );
  }
}
