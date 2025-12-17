import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/api_constants.dart';

class MyJobsScreen extends ConsumerStatefulWidget {
  const MyJobsScreen({super.key});

  @override
  ConsumerState<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends ConsumerState<MyJobsScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}/jobs/available',
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
        final List<dynamic> jobsData = data['data'] ?? [];

        setState(() {
          _jobs = jobsData.map((job) => job as Map<String, dynamic>).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading jobs: $e');
      String errorMessage = 'Failed to load jobs';

      if (e is DioException) {
        if (e.response != null) {
          errorMessage =
              e.response?.data['message'] ??
              'Server error: ${e.response?.statusCode}';
        } else {
          errorMessage = 'Network error: ${e.message}';
        }
      }

      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Jobs', style: AppTextStyles.appBarTitle),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadJobs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: AppColors.error),
                  const SizedBox(height: AppDimensions.spacing24),
                  Text(
                    _error!,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),
                  ElevatedButton(
                    onPressed: _loadJobs,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _jobs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 80,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppDimensions.spacing24),
                  Text(
                    'No jobs available',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingLarge,
                    ),
                    child: Text(
                      'Jobs matching your service category will appear here',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadJobs,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  final job = _jobs[index];
                  return _buildJobCard(job);
                },
              ),
            ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final homeowner = job['homeowner'] as Map<String, dynamic>?;
    final homeownerName = homeowner != null
        ? '${homeowner['first_name']} ${homeowner['last_name']}'
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job['title'] ?? 'Untitled Job',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing8,
                    vertical: AppDimensions.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                  child: Text(
                    job['status']?.toString().toUpperCase() ?? 'OPEN',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing8),
            if (job['description'] != null &&
                job['description'].toString().isNotEmpty)
              Text(
                job['description'],
                style: AppTextStyles.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppDimensions.spacing12),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: AppDimensions.iconSmall,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimensions.spacing4),
                Text(
                  homeownerName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: AppDimensions.iconSmall,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimensions.spacing4),
                Expanded(
                  child: Text(
                    job['address'] ?? 'No address',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.push('/job-details', extra: job);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
