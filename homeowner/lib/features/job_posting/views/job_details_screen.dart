import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import 'view_applications.dart';

class JobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  int _applicationsCount = 0;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _applicationsCount = widget.job['applications_count'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Job data: ${widget.job}');

    // Safety check for job data
    if (widget.job.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: const Center(child: Text('No job data available')),
      );
    }

    final category = widget.job['category'] as Map<String, dynamic>?;
    final services = widget.job['services'] as List<dynamic>?;
    final photos = widget.job['photos'] as List<dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Job Details', style: AppTextStyles.appBarTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit job
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit feature coming soon!')),
              );
            },
          ),
        ],
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
                    color: Colors.black.withOpacity(0.05),
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
                          ).withOpacity(0.1),
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
                          backgroundColor: AppColors.primaryLight.withOpacity(
                            0.3,
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

                  // Applications Section
                  _buildSectionTitle('Applications'),
                  const SizedBox(height: AppDimensions.spacing12),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMedium,
                      ),
                      border: Border.all(color: AppColors.grey300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: AppDimensions.iconLarge,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppDimensions.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Applications',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_applicationsCount ${_applicationsCount == 1 ? "tradie" : "tradies"} applied',
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: ElevatedButton(
                            onPressed: _applicationsCount > 0
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ViewApplicationsScreen(
                                              jobId: widget.job['id'],
                                              jobTitle: widget.job['title'],
                                            ),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.spacing8,
                              ),
                            ),
                            child: const Text('View'),
                          ),
                        ),
                      ],
                    ),
                  ),
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
              color: Colors.black.withOpacity(0.05),
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
                  onPressed: _isDeleting
                      ? null
                      : () {
                          _showDeleteConfirmation(context);
                        },
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(_isDeleting ? 'Deleting...' : 'Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isDeleting
                        ? AppColors.onSurfaceVariant
                        : AppColors.error,
                    side: BorderSide(
                      color: _isDeleting
                          ? AppColors.onSurfaceVariant
                          : AppColors.error,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.paddingMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.job['status'] == 'open'
                      ? () {
                          // TODO: Close job
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Close job feature coming soon!'),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.close),
                  label: Text(
                    widget.job['status'] == 'open' ? 'Close Job' : 'Closed',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
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

  Future<void> _deleteJob() async {
    if (_isDeleting) return; // Prevent multiple delete attempts

    setState(() {
      _isDeleting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final dio = Dio();
      final response = await dio.delete(
        '${ApiConstants.baseUrl}/jobs/job-offers/${widget.job['id']}',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Job deleted successfully!'),
              backgroundColor: AppColors.success,
            ),
          );

          // Navigate back to job list
          Navigator.of(context).pop(true); // Return true to indicate deletion
        }
      }
    } catch (e) {
      debugPrint('Error deleting job: $e');

      String errorMessage = 'Failed to delete job';
      if (e is DioException && e.response != null) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }

      if (mounted) {
        setState(() {
          _isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final applicationsCount = _applicationsCount;
    final jobStatus = widget.job['status'] as String?;

    // If job is completed, it likely has accepted applications
    if (jobStatus == 'completed') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Job'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 48),
              const SizedBox(height: 16),
              const Text(
                'This job cannot be deleted because it has been completed or has accepted applications.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'If you need to cancel the work, please contact the tradie directly.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this job?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            // Show warning if job has applications
            if (applicationsCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This job has $applicationsCount ${applicationsCount == 1 ? 'application' : 'applications'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Show warning if job is completed
            if (jobStatus == 'completed') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This job is marked as completed',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            const Text(
              'This will permanently delete:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '• The job posting',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (applicationsCount > 0)
              Text(
                '• All $applicationsCount ${applicationsCount == 1 ? 'application' : 'applications'}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            const Text(
              '• All related photos and data',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteJob();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
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
