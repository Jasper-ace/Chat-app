import 'package:flutter/material.dart';
import 'package:homeowner/features/job_posting/models/job_posting_models.dart';

class JobTypeToggle extends StatelessWidget {
  final JobType currentType;
  final Function(JobType) onChanged;

  const JobTypeToggle({
    super.key,
    required this.currentType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildToggleButton(
            label: 'Standard Job',
            icon: Icons.work_outline,
            isSelected: currentType == JobType.standard,
            onTap: () => onChanged(JobType.standard),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildToggleButton(
            label: 'Recurring Job',
            icon: Icons.repeat,
            isSelected: currentType == JobType.recurrent,
            onTap: () => onChanged(JobType.recurrent),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final borderColor = isSelected
        ? const Color(0xFF2196F3)
        : const Color(0xFFE6E6E6);
    final backgroundColor = isSelected ? const Color(0xFFE3F2FD) : Colors.white;
    final iconColor = isSelected ? const Color(0xFF2196F3) : Colors.black54;
    final textColor = isSelected ? const Color(0xFF2196F3) : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
