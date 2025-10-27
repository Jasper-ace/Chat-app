import 'package:flutter/material.dart';

class JobConfirmationWidget extends StatelessWidget {
  final String jobTitle;
  final String status;
  final VoidCallback? onTap;

  const JobConfirmationWidget({
    super.key,
    required this.jobTitle,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Job $status: $jobTitle',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
