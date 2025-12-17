import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homeowner/core/services/photo_service.dart';
import 'package:homeowner/features/job_posting/models/job_posting_models.dart';
import 'package:homeowner/features/job_posting/viewmodels/job_posting_viewmodel.dart';
import 'package:homeowner/features/job_posting/views/widgets/job_type_toggle.dart';

class JobPostFormScreen extends ConsumerStatefulWidget {
  final bool isEditMode;
  final int? jobId;
  final Map<String, dynamic>? initialData;

  const JobPostFormScreen({
    super.key,
    this.isEditMode = false,
    this.jobId,
    this.initialData,
  });

  @override
  ConsumerState<JobPostFormScreen> createState() => _JobPostFormScreenState();
}

class _JobPostFormScreenState extends ConsumerState<JobPostFormScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to initialize after build is complete
    Future.microtask(() {
      if (widget.isEditMode && widget.initialData != null) {
        _populateFormFromInitialData();
      } else {
        _initializeFromFormData();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _populateFormFromInitialData() {
    try {
      if (widget.initialData == null) return;

      final viewModel = ref.read(jobPostingViewModelProvider.notifier);
      final data = widget.initialData!;

      // Update local controllers
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _addressController.text = data['address'] ?? '';

      // Update viewmodel with initial data
      viewModel.loadInitialDataIntoForm(data);

      // Load categories if needed (but don't wait for it)
      final state = ref.read(jobPostingViewModelProvider);
      if (state.categories == null || state.categories!.isEmpty) {
        // Schedule category loading for later
        Future.microtask(() {
          viewModel.loadCategories();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load form data: $e';
        });
      }
    }
  }

  void _initializeFromFormData() {
    final formData = ref.read(jobPostingViewModelProvider).formData;
    final viewModel = ref.read(jobPostingViewModelProvider.notifier);

    _titleController.text = formData.title;
    _descriptionController.text = formData.description ?? '';
    _addressController.text = formData.address;

    // Load categories from database
    Future.microtask(() {
      viewModel.loadCategories();
    });

    // Don't set default category - let user select from real database categories

    // Load services if a category is selected
    if (formData.selectedCategory != null) {
      Future.microtask(() {
        viewModel.loadServicesByCategory(formData.selectedCategory!.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    return _buildFormScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEditMode ? 'Edit Job' : 'Post a Job',
          style: const TextStyle(
            color: Colors.black,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEditMode ? 'Edit Job' : 'Post a Job',
          style: const TextStyle(
            color: Colors.black,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                Future.microtask(() {
                  if (widget.isEditMode && widget.initialData != null) {
                    _populateFormFromInitialData();
                  } else {
                    _initializeFromFormData();
                  }
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormScreen() {
    final state = ref.watch(jobPostingViewModelProvider);
    final formData = state.formData;
    final viewModel = ref.read(jobPostingViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEditMode ? 'Edit Job' : 'Post a Job',
          style: const TextStyle(
            color: Colors.black,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.isEditMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteDialog(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rest of your form...
            JobTypeToggle(
              currentType: formData.jobType,
              onChanged: (type) => viewModel.updateJobType(type),
            ),
            const SizedBox(height: 24),

            // Date pickers
            _buildDateSections(formData, viewModel),
            const SizedBox(height: 24),

            // Category Selection
            _buildCategorySelectionField(state, viewModel),
            const SizedBox(height: 24),

            // Job Information
            Row(
              children: [
                Icon(
                  Icons.work_outline,
                  color: const Color(0xFF2196F3),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Job Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                    color: Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _titleController,
              label: 'Job Title',
              hint: 'e.g. Light Installation',
              onChanged: viewModel.updateTitle,
            ),
            const SizedBox(height: 16),

            _buildServicesField(formData, context),
            const SizedBox(height: 16),

            _buildJobSizeSelector(viewModel, formData.jobSize),
            const SizedBox(height: 16),

            _buildDescriptionField(viewModel),
            const SizedBox(height: 24),

            // Address
            _buildSection(
              title: 'Address',
              icon: Icons.location_on_outlined,
              child: TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Enter your address',
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: const Color(0xFF2196F3),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF2196F3),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: viewModel.updateAddress,
              ),
            ),
            const SizedBox(height: 24),

            // Photo Upload Section
            _buildPhotoUploadSection(formData, viewModel),

            // Existing photos in edit mode
            if (widget.isEditMode && formData.existingPhotoUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildExistingPhotosSection(formData),
            ],

            const SizedBox(height: 32),

            // Submit/Update Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () => widget.isEditMode
                          ? _updateForm(viewModel, formData)
                          : _submitForm(viewModel, formData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        widget.isEditMode ? 'Update Job' : 'Post Job',
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'Roboto',
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget methods

  Widget _buildDateSections(
    JobPostFormData formData,
    JobPostingViewModel viewModel,
  ) {
    if (formData.jobType == JobType.standard) {
      return _buildDateSection(
        title: 'Preferred Date',
        selectedDate: formData.preferredDate,
        onTap: () => _selectDate(context, viewModel, isStandard: true),
      );
    } else if (formData.jobType == JobType.recurrent) {
      return Column(
        children: [
          _buildDateSection(
            title: 'Preferred Start Date',
            selectedDate: formData.startDate,
            onTap: () => _selectDate(context, viewModel, isStartDate: true),
          ),
          const SizedBox(height: 16),
          _buildDateSection(
            title: 'End Date (Optional)',
            selectedDate: formData.endDate,
            onTap: () => _selectDate(context, viewModel, isEndDate: true),
          ),
          const SizedBox(height: 16),
          _buildFrequencySelector(viewModel, formData.frequency),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildDateSection({
    required String title,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: const Color(0xFF2196F3),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE6E6E6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null ? _formatDate(selectedDate) : 'mm/dd/yy',
                  style: TextStyle(
                    color: selectedDate != null ? Colors.black : Colors.black54,
                    fontFamily: 'Roboto',
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}";
  }

  Widget _buildFrequencySelector(
    JobPostingViewModel viewModel,
    Frequency? currentFrequency,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.repeat, color: const Color(0xFF2196F3), size: 18),
            const SizedBox(width: 6),
            const Text(
              'Frequency',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Frequency>(
          initialValue: currentFrequency,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          hint: const Text('Select Frequency'),
          items: Frequency.values
              .map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(_getFrequencyLabel(f)),
                ),
              )
              .toList(),
          onChanged: viewModel.updateFrequency,
        ),
      ],
    );
  }

  String _getFrequencyLabel(Frequency frequency) {
    switch (frequency) {
      case Frequency.daily:
        return 'Daily';
      case Frequency.weekly:
        return 'Weekly';
      case Frequency.monthly:
        return 'Monthly';
      case Frequency.quarterly:
        return 'Quarterly';
      case Frequency.yearly:
        return 'Yearly';
      case Frequency.custom:
        return 'Custom';
    }
  }

  Widget _buildJobSizeSelector(
    JobPostingViewModel viewModel,
    JobSize currentSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.straighten, color: const Color(0xFF2196F3), size: 18),
            const SizedBox(width: 6),
            const Text(
              'Estimated Job Size',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<JobSize>(
          initialValue: currentSize,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          hint: const Text('Select Job Size'),
          items: JobSize.values
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(_getJobSizeLabel(s)),
                ),
              )
              .toList(),
          onChanged: (value) => viewModel.updateJobSize(value!),
        ),
      ],
    );
  }

  String _getJobSizeLabel(JobSize size) {
    switch (size) {
      case JobSize.small:
        return 'Small (Few hours)';
      case JobSize.medium:
        return 'Medium (Half day)';
      case JobSize.large:
        return 'Large (Full day+)';
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.title, color: const Color(0xFF2196F3), size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildServicesField(JobPostFormData formData, BuildContext context) {
    final state = ref.watch(jobPostingViewModelProvider);
    final viewModel = ref.read(jobPostingViewModelProvider.notifier);

    // Get available services for the selected category
    final availableServices = state.servicesForCategory ?? <ServiceModel>[];

    // If no category is selected, show message
    if (formData.selectedCategory == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_outlined,
                color: const Color(0xFF2196F3),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Services',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE6E6E6)),
            ),
            child: const Text(
              'Please select a category first',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    // Create a map for easy lookup and ensure uniqueness
    final Map<int, ServiceModel> serviceMap = {};
    for (final service in availableServices) {
      serviceMap[service.id] = service;
    }
    final uniqueServices = serviceMap.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.build_outlined,
              color: const Color(0xFF2196F3),
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              'Services',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: uniqueServices.isEmpty
                ? 'Loading services...'
                : 'Select a service',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: uniqueServices.isEmpty
              ? null
              : uniqueServices.map((service) {
                  return DropdownMenuItem<int>(
                    value: service.id,
                    child: Text(service.name),
                  );
                }).toList(),
          onChanged: uniqueServices.isEmpty
              ? null
              : (int? selectedServiceId) {
                  if (selectedServiceId != null) {
                    final selectedService = serviceMap[selectedServiceId];
                    if (selectedService != null) {
                      // Add the selected service to the list
                      final currentServices = List<ServiceModel>.from(
                        formData.selectedServices,
                      );
                      if (!currentServices.any(
                        (s) => s.id == selectedService.id,
                      )) {
                        currentServices.add(selectedService);
                        viewModel.selectServices(currentServices);
                      }
                    }
                  }
                },
        ),
        // Show selected services as chips
        if (formData.selectedServices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: formData.selectedServices.map((service) {
              return Chip(
                label: Text(service.name, style: const TextStyle(fontSize: 12)),
                backgroundColor: const Color(0xFFE3F2FD),
                labelStyle: const TextStyle(color: Color(0xFF2196F3)),
                deleteIcon: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFF2196F3),
                ),
                onDeleted: () {
                  final updatedServices = formData.selectedServices
                      .where((s) => s.id != service.id)
                      .toList();
                  viewModel.selectServices(updatedServices);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionField(JobPostingViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: const Color(0xFF2196F3),
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Enter job description here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          onChanged: viewModel.updateDescription,
        ),
        const SizedBox(height: 8),
        Text(
          '${_descriptionController.text.length}/300 characters',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildPhotoUploadSection(
    JobPostFormData formData,
    JobPostingViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_camera_outlined,
              color: const Color(0xFF2196F3),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Upload Photos (${formData.photoFiles.length}/5)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 5,
          itemBuilder: (context, index) {
            final hasPhoto = index < formData.photoFiles.length;
            return GestureDetector(
              onTap: () => _showPhotoPicker(context, viewModel),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFF007BFF),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: hasPhoto
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          formData.photoFiles[index],
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.add,
                          color: Color(0xFF007BFF),
                          size: 32,
                        ),
                      ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Maximum 5 photos, 5MB each',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildExistingPhotosSection(JobPostFormData formData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existing Photos (${formData.existingPhotoUrls.length})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: formData.existingPhotoUrls.length,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  formData.existingPhotoUrls[index],
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Existing photos will be kept unless replaced',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: const Color(0xFF2196F3), size: 18),
              const SizedBox(width: 6),
            ],
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    JobPostingViewModel viewModel, {
    bool isStandard = false,
    bool isStartDate = false,
    bool isEndDate = false,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      if (isStandard) {
        viewModel.updatePreferredDate(picked);
      } else if (isStartDate) {
        viewModel.updateStartDate(picked);
      } else if (isEndDate) {
        viewModel.updateEndDate(picked);
      }
      setState(() {});
    }
  }

  void _submitForm(
    JobPostingViewModel viewModel,
    JobPostFormData formData,
  ) async {
    final validationError = viewModel.getFormValidationError();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red),
      );
      return;
    }

    final success = await viewModel.createJobPost();
    if (success && context.mounted) {
      // Navigate to success screen instead of showing snackbar
      context.go('/job-success');
    } else if (context.mounted) {
      final state = ref.read(jobPostingViewModelProvider);
      final errorMessage = state.error ?? 'Failed to post job. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  void _updateForm(
    JobPostingViewModel viewModel,
    JobPostFormData formData,
  ) async {
    final validationError = viewModel.getFormValidationError();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    if (widget.jobId == null) return;

    final success = await viewModel.updateJobPost(widget.jobId!);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update job. Try again.')),
      );
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text(
          'Are you sure you want to delete this job? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.jobId != null) {
                final success = await ref
                    .read(jobPostingViewModelProvider.notifier)
                    .deleteJobOffer(widget.jobId!);

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Job deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPhotoPicker(BuildContext context, JobPostingViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                final photos = await PhotoService.pickImages();
                if (photos.isNotEmpty) viewModel.addPhotoFiles(photos);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () async {
                final photo = await PhotoService.takePhoto();
                if (photo != null) viewModel.addPhotoFiles([photo]);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelectionField(
    JobPostingState state,
    JobPostingViewModel viewModel,
  ) {
    final categories = state.categories ?? [];
    final selectedCategory = state.formData.selectedCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category_outlined,
              color: const Color(0xFF2196F3),
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: selectedCategory?.id,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Select a category',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: categories.map((category) {
            return DropdownMenuItem<int>(
              value: category.id,
              child: Text(category.name),
            );
          }).toList(),
          onChanged: (int? categoryId) {
            if (categoryId != null) {
              final category = categories.firstWhere((c) => c.id == categoryId);
              final updatedFormData = state.formData.copyWith(
                selectedCategory: category,
                selectedServices: [], // Clear services when category changes
              );
              viewModel.updateFormData(updatedFormData);
              // Load services for the selected category
              viewModel.loadServicesByCategory(categoryId);
            }
          },
        ),
        if (state.isLoading && categories.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Loading categories...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
