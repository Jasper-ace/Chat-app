import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/api_constants.dart';
import '../auth/services/tradie_api_auth_service.dart';

class JobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  final _authService = TradieApiAuthService();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isApplying = false;

  Future<void> _applyForJob() async {
    if (_isApplying) return;

    setState(() => _isApplying = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final jobId = widget.job['id'];
      final dio = Dio();

      final response = await dio.post(
        '${ApiConstants.baseUrl}/jobs/$jobId/apply',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        // Update the job data to reflect application
        setState(() {
          widget.job['has_applied'] = true;
          widget.job['application_status'] = 'pending';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Failed to submit application';
      if (e is DioException && e.response != null) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _contactHomeowner() async {
    final homeowner = widget.job['homeowner'] as Map<String, dynamic>?;
    if (homeowner == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Homeowner information not available')),
      );
      return;
    }

    try {
      final userId = await _authService.getUserId();
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      final homeownerId = homeowner['id'] as int;

      // Check Firebase for existing thread
      final threadsSnapshot = await _database.child('threads').get();
      String? existingThreadId;

      if (threadsSnapshot.exists) {
        final threadsData = threadsSnapshot.value as Map<dynamic, dynamic>;

        // Find thread where tradie_id matches current user and homeowner_id matches target
        for (var entry in threadsData.entries) {
          final thread = entry.value as Map<dynamic, dynamic>;
          if (thread['tradie_id'] == userId &&
              thread['homeowner_id'] == homeownerId) {
            existingThreadId = entry.key as String;
            break;
          }
        }
      }

      // Use existing thread ID or create temporary one
      final chatId = existingThreadId ?? 'new_${userId}_$homeownerId';

      if (!mounted) return;

      // Navigate to chat screen
      context.push(
        '/chat/$chatId',
        extra: {
          'otherUserName':
              '${homeowner['first_name'] ?? ''} ${homeowner['last_name'] ?? ''}'
                  .trim(),
          'otherUserId': homeownerId.toString(),
          'otherUserType': 'homeowner',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeowner = widget.job['homeowner'] as Map<String, dynamic>?;
    final category = widget.job['category'] as Map<String, dynamic>?;
    final services = widget.job['services'] as List<dynamic>?;
    final photos = widget.job['photos'] as List<dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Job Details', style: AppTextStyles.appBarTitle),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.job['title'] ?? 'Untitled Job',
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacing12,
                          vertical: AppDimensions.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            widget.job['status'],
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMedium,
                          ),
                        ),
                        child: Text(
                          widget.job['status']?.toString().toUpperCase() ??
                              'OPEN',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: _getStatusColor(widget.job['status']),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (category != null) ...[
                    const SizedBox(height: AppDimensions.spacing8),
                    Text(
                      category['name'] ?? '',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Job Details Section
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (widget.job['description'] != null &&
                      widget.job['description'].toString().isNotEmpty) ...[
                    _buildSectionTitle('Description'),
                    const SizedBox(height: AppDimensions.spacing8),
                    Text(
                      widget.job['description'],
                      style: AppTextStyles.bodyLarge,
                    ),
                    const SizedBox(height: AppDimensions.spacing24),
                  ],

                  // Job Type & Size
                  _buildSectionTitle('Job Information'),
                  const SizedBox(height: AppDimensions.spacing12),
                  _buildInfoRow(
                    Icons.work_outline,
                    'Job Type',
                    _formatJobType(widget.job['job_type']),
                  ),
                  const SizedBox(height: AppDimensions.spacing8),
                  _buildInfoRow(
                    Icons.straighten_outlined,
                    'Job Size',
                    _formatJobSize(widget.job['job_size']),
                  ),
                  if (widget.job['preferred_date'] != null) ...[
                    const SizedBox(height: AppDimensions.spacing8),
                    _buildInfoRow(
                      Icons.calendar_today_outlined,
                      'Preferred Date',
                      _formatDate(widget.job['preferred_date']),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacing24),

                  // Location
                  _buildSectionTitle('Location'),
                  const SizedBox(height: AppDimensions.spacing12),
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    'Address',
                    widget.job['address'] ?? 'No address provided',
                  ),
                  const SizedBox(height: AppDimensions.spacing24),

                  // Services
                  if (services != null && services.isNotEmpty) ...[
                    _buildSectionTitle('Required Services'),
                    const SizedBox(height: AppDimensions.spacing12),
                    Wrap(
                      spacing: AppDimensions.spacing8,
                      runSpacing: AppDimensions.spacing8,
                      children: services.map((service) {
                        return Chip(
                          label: Text(
                            service['name'] ?? '',
                            style: AppTextStyles.bodySmall,
                          ),
                          backgroundColor: AppColors.primaryLight.withValues(
                            alpha: 0.3,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppDimensions.spacing24),
                  ],

                  // Photos
                  if (photos != null && photos.isNotEmpty) ...[
                    _buildSectionTitle('Photos'),
                    const SizedBox(height: AppDimensions.spacing12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(
                              right: AppDimensions.spacing12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMedium,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMedium,
                              ),
                              child: Image.network(
                                photo['file_path'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.image_not_supported),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacing24),
                  ],

                  // Homeowner Information
                  if (homeowner != null) ...[
                    _buildSectionTitle('Posted By'),
                    const SizedBox(height: AppDimensions.spacing12),
                    Container(
                      padding: const EdgeInsets.all(
                        AppDimensions.paddingMedium,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMedium,
                        ),
                        border: Border.all(color: AppColors.grey300),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.person_outline,
                            'Name',
                            '${homeowner['first_name']} ${homeowner['last_name']}',
                          ),
                          if (homeowner['email'] != null) ...[
                            const SizedBox(height: AppDimensions.spacing8),
                            _buildInfoRow(
                              Icons.email_outlined,
                              'Email',
                              homeowner['email'],
                            ),
                          ],
                          if (homeowner['phone'] != null) ...[
                            const SizedBox(height: AppDimensions.spacing8),
                            _buildInfoRow(
                              Icons.phone_outlined,
                              'Phone',
                              homeowner['phone'],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _contactHomeowner,
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('Contact'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.paddingMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (widget.job['has_applied'] == true || _isApplying)
                      ? null
                      : _applyForJob,
                  icon: _isApplying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Icon(
                          widget.job['has_applied'] == true
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                        ),
                  label: Text(
                    widget.job['has_applied'] == true ? 'Applied' : 'Apply',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.job['has_applied'] == true
                        ? AppColors.success
                        : AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.paddingMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: AppDimensions.iconSmall,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(width: AppDimensions.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'open':
        return AppColors.success;
      case 'in_progress':
        return AppColors.warning;
      case 'completed':
        return AppColors.info;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  String _formatJobType(String? jobType) {
    if (jobType == null) return 'Standard';
    return jobType
        .split('_')
        .map((word) {
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _formatJobSize(String? jobSize) {
    if (jobSize == null) return 'Medium';
    return jobSize[0].toUpperCase() + jobSize.substring(1);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Not specified';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
