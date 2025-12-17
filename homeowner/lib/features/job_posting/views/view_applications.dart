import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../chat/repositories/chat_repository_realtime.dart';

class ViewApplicationsScreen extends StatefulWidget {
  final int jobId;
  final String jobTitle;

  const ViewApplicationsScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<ViewApplicationsScreen> createState() => _ViewApplicationsScreenState();
}

class _ViewApplicationsScreenState extends State<ViewApplicationsScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}/jobs/${widget.jobId}/applications',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> applicationsData = data['data'] ?? [];

        setState(() {
          _applications = applicationsData
              .map((app) => app as Map<String, dynamic>)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading applications: $e');
      setState(() {
        _error = 'Failed to load applications';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Applications', style: AppTextStyles.appBarTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: Column(
        children: [
          // Job Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.jobTitle,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Text(
                  '${_applications.length} ${_applications.length == 1 ? "application" : "applications"}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Applications List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: AppDimensions.spacing24),
                        Text(
                          _error!,
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing16),
                        ElevatedButton(
                          onPressed: _loadApplications,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _applications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 80,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing24),
                        Text(
                          'No applications yet',
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        Text(
                          'Tradies will appear here when they apply',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadApplications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(
                        AppDimensions.paddingMedium,
                      ),
                      itemCount: _applications.length,
                      itemBuilder: (context, index) {
                        final application = _applications[index];
                        return _buildApplicationCard(application);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final tradie = application['tradie'] as Map<String, dynamic>?;
    final status = application['status'] as String? ?? 'pending';
    final createdAt = application['created_at'] as String?;
    final coverLetter = application['cover_letter'] as String?;
    final proposedPrice = application['proposed_price'];

    final tradieName = tradie != null
        ? '${tradie['first_name'] ?? ''} ${tradie['last_name'] ?? ''}'.trim()
        : 'Unknown Tradie';

    final businessName = tradie?['business_name'] ?? 'No business name';

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tradieName,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        businessName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing8,
                    vertical: AppDimensions.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.spacing12),

            // Application details
            if (proposedPrice != null) ...[
              _buildDetailRow(
                Icons.attach_money,
                'Proposed Price',
                '\$$proposedPrice',
              ),
              const SizedBox(height: AppDimensions.spacing8),
            ],

            if (createdAt != null) ...[
              _buildDetailRow(
                Icons.schedule,
                'Applied',
                _formatDate(createdAt),
              ),
              const SizedBox(height: AppDimensions.spacing8),
            ],

            if (coverLetter != null && coverLetter.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                'Cover Letter:',
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                coverLetter,
                style: AppTextStyles.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: AppDimensions.spacing16),

            // Action buttons
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateApplicationStatus(
                        application['id'],
                        'rejected',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showAcceptConfirmation(
                        application['id'],
                        tradieName,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: AppDimensions.iconSmall,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(width: AppDimensions.spacing8),
        Text(
          '$label: ',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'withdrawn':
        return AppColors.onSurfaceVariant;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy \'at\' h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _showAcceptConfirmation(
    int applicationId,
    String tradieName,
  ) async {
    // Count other pending applications
    final otherPendingCount = _applications
        .where(
          (app) => app['id'] != applicationId && app['status'] == 'pending',
        )
        .length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Accept Application'),
          content: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurface,
              ),
              children: [
                const TextSpan(text: 'Accept application from '),
                TextSpan(
                  text: tradieName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '?\n\n'),
                if (otherPendingCount > 0) ...[
                  TextSpan(
                    text: 'Note: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  TextSpan(
                    text:
                        '$otherPendingCount other pending ${otherPendingCount == 1 ? 'application' : 'applications'} will be automatically rejected.',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateApplicationStatus(applicationId, 'accepted');
    }
  }

  Future<bool> _sendAcceptanceMessage(Map<String, dynamic> application) async {
    try {
      debugPrint('🚀 Starting Realtime Database acceptance message process...');
      debugPrint('📋 Application data: $application');

      // Get homeowner ID from SharedPreferences (more reliable than Firebase)
      final prefs = await SharedPreferences.getInstance();
      final homeownerIdInt = prefs.getInt('user_id');
      debugPrint('🏠 Homeowner ID from SharedPreferences: $homeownerIdInt');

      if (homeownerIdInt == null) {
        debugPrint('❌ Could not get homeowner ID from SharedPreferences');
        return false;
      }

      // Get tradie data from application
      final tradie = application['tradie'] as Map<String, dynamic>?;
      debugPrint('👷 Tradie data: $tradie');

      if (tradie == null) {
        debugPrint('❌ Could not get tradie data from application');
        return false;
      }

      final tradieIdInt = tradie['id'] as int?;
      debugPrint('👷 Tradie ID: $tradieIdInt');

      if (tradieIdInt == null) {
        debugPrint('❌ Could not get tradie ID from tradie data');
        return false;
      }

      // Create the acceptance message
      final message =
          "Hello! Your application for '${widget.jobTitle}' has been accepted. Please expect further instructions regarding the schedule and requirements. Thank you!";
      debugPrint('💬 Message to send: $message');

      // Use ChatRepository (Realtime Database + Laravel API)
      debugPrint('📡 Creating ChatRepository instance...');
      final chatRepository = ChatRepository();
      debugPrint('📡 ChatRepository created successfully');

      // Create or get chat room first
      debugPrint('🔄 Creating/getting chat room...');
      final chatId = await chatRepository.createRoom(
        tradieId: tradieIdInt,
        homeownerId: homeownerIdInt,
      );
      debugPrint('🆔 Chat ID: $chatId');

      if (chatId == null) {
        debugPrint('❌ Failed to create/get chat room');
        return false;
      }

      // Send the acceptance message through Laravel API (which writes to Realtime Database)
      debugPrint(
        '📤 Sending message through Laravel API to Realtime Database...',
      );
      final success = await chatRepository.sendMessage(
        senderId: homeownerIdInt,
        receiverId: tradieIdInt,
        senderType: 'homeowner',
        receiverType: 'tradie',
        message: message,
        chatId: chatId,
      );

      if (success) {
        debugPrint(
          '✅ Acceptance message sent successfully to Realtime Database',
        );
        return true;
      } else {
        debugPrint('❌ Failed to send message through Laravel API');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending Realtime Database acceptance message: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }



  Future<void> _updateApplicationStatus(
    int applicationId,
    String status,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final dio = Dio();
      final response = await dio.put(
        '${ApiConstants.baseUrl}/jobs/${widget.jobId}/applications/$applicationId',
        data: {'status': status},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        bool messageSent = false;

        // If accepting an application, send the acceptance message through chat
        if (status == 'accepted') {
          final application = _applications.firstWhere(
            (app) => app['id'] == applicationId,
            orElse: () => <String, dynamic>{},
          );

          if (application.isNotEmpty) {
            messageSent = await _sendAcceptanceMessage(application);
          }

          // Reload the entire list to show auto-rejected applications
          await _loadApplications();
        } else {
          // For rejection, just update the local status
          setState(() {
            final applicationIndex = _applications.indexWhere(
              (app) => app['id'] == applicationId,
            );
            if (applicationIndex != -1) {
              _applications[applicationIndex]['status'] = status;
            }
          });
        }

        if (mounted) {
          String message;
          if (status == 'accepted') {
            if (messageSent) {
              message =
                  'Application accepted! Acceptance message sent to tradie. Job is now completed and other pending applications have been automatically rejected.';
            } else {
              message =
                  'Application accepted! Job is now completed and other pending applications have been automatically rejected. (Note: Message sending failed - please contact the tradie directly)';
            }
          } else {
            message = 'Application rejected successfully!';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: status == 'accepted'
                  ? (messageSent ? AppColors.success : AppColors.warning)
                  : AppColors.warning,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating application status: $e');

      String errorMessage = 'Failed to update application';
      if (e is DioException && e.response != null) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

extension StringCapitalize on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
