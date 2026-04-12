import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/semester_registration.dart';
import '../../services/semester_registration_service.dart';

class SemesterRegistrationReviewTab extends StatelessWidget {
  final String adminId;
  final Future<void> Function() onChanged;

  const SemesterRegistrationReviewTab({
    super.key,
    required this.adminId,
    required this.onChanged,
  });

  Future<void> _reject(BuildContext context, SemesterRegistrationRecord record) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Registration'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Rejection reason',
              hintText: 'Explain why the request is being rejected',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(reasonController.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;
    await SemesterRegistrationService.instance.reviewRegistration(
      registrationId: record.id,
      adminId: adminId,
      approve: false,
      rejectionReason: reason,
    );
    await onChanged();
  }

  Future<void> _approve(SemesterRegistrationRecord record) async {
    await SemesterRegistrationService.instance.reviewRegistration(
      registrationId: record.id,
      adminId: adminId,
      approve: true,
    );
    await onChanged();
  }

  Future<void> _resetCycle(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset upcoming registration cycle?'),
          content: const Text(
            'This removes approved upcoming courses and clears semester registration requests, while keeping current enrollments unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await SemesterRegistrationService.instance.resetUpcomingRegistrationCycle();
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SemesterRegistrationRecord>>(
      stream: SemesterRegistrationService.instance.streamPendingRegistrations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center));
        }

        final items = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _resetCycle(context),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset Upcoming Cycle'),
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.only(top: 36),
                child: Text('No pending semester registrations.'),
              ))
            else
              ...items.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.studentName.isNotEmpty ? record.studentName : record.studentId,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    record.studentEmail.isNotEmpty ? record.studentEmail : record.studentId,
                                    style: const TextStyle(color: AppColors.ink500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Semester ${record.targetSemester}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Selected courses: ${record.selectedCourseNames.isEmpty ? record.selectedCourseIds.join(', ') : record.selectedCourseNames.join(', ')}'),
                        const SizedBox(height: 6),
                        Text('Backlog courses: ${record.backlogCourseNames.isEmpty ? 'None' : record.backlogCourseNames.join(', ')}'),
                        const SizedBox(height: 6),
                        Text('Credits: ${record.totalCredits}/${record.creditLimit}'),
                        if (record.totalCredits > record.creditLimit) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Validation warning: credit limit exceeded.',
                            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _reject(context, record),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _approve(record),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
