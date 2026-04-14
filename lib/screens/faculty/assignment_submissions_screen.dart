import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../models/assignment.dart';
import '../../services/faculty_module_service.dart';

class AssignmentSubmissionsScreen extends StatefulWidget {
  final AssignmentModel assignment;
  final String courseCode;
  final int totalStudents;

  const AssignmentSubmissionsScreen({
    super.key,
    required this.assignment,
    required this.courseCode,
    required this.totalStudents,
  });

  @override
  State<AssignmentSubmissionsScreen> createState() => _AssignmentSubmissionsScreenState();
}

class _AssignmentSubmissionsScreenState extends State<AssignmentSubmissionsScreen> {
  final FacultyModuleService _service = FacultyModuleService.instance;
  late Future<List<AssignmentAttemptSummary>> _futureSubmissions;

  @override
  void initState() {
    super.initState();
    _futureSubmissions = _service.fetchAssignmentAttempts(
      widget.assignment.assignmentId,
    );
  }

  void _refresh() {
    setState(() {
      _futureSubmissions = _service.fetchAssignmentAttempts(
        widget.assignment.assignmentId,
      );
    });
  }

  void _openFile(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the file')),
        );
      }
    }
  }

  void _openGradingSheet(AssignmentAttemptSummary attempt) {
    int? marks = attempt.submission.marksObtained;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grade Submission',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                attempt.studentName,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
              ),
              Text(attempt.studentEmail, style: const TextStyle(color: AppColors.ink500)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.ink100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.attach_file, color: AppColors.primaryDark),
                ),
                title: const Text('View Student Work'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFile(attempt.submission.fileUrl),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: marks?.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Marks (out of ${attempt.totalMarks})',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  marks = int.tryParse(val);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (marks != null) {
                      if (marks! < 0 || marks! > attempt.totalMarks) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Marks must be between 0 and ${attempt.totalMarks}')),
                        );
                        return;
                      }
                      
                      Navigator.pop(context);
                      try {
                        await _service.gradeAssignmentSubmission(attempt.submission.id, marks!);
                        _refresh();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Grade saved successfully')),
                        );
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving grade: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save Grade'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      appBar: AppBar(
        title: const Text('Submissions'),
        backgroundColor: AppColors.surfaceWarm,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<List<AssignmentAttemptSummary>>(
        future: _futureSubmissions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final attempts = snapshot.data ?? [];
          final gradedCount = attempts.where((a) => a.submission.marksObtained != null).length;

          return RefreshIndicator(
            onRefresh: () async { _refresh(); },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOverviewCard(attempts.length, gradedCount),
                const SizedBox(height: 24),
                const Text(
                  'Submitted Work',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink900,
                  ),
                ),
                const SizedBox(height: 12),
                if (attempts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No submissions yet.', style: TextStyle(color: AppColors.ink500)),
                    ),
                  )
                else
                  ...attempts.map((attempt) {
                    final graded = attempt.submission.marksObtained != null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        onTap: () => _openGradingSheet(attempt),
                        leading: CircleAvatar(
                          backgroundColor: graded ? AppColors.success.withOpacity(0.12) : AppColors.warning.withOpacity(0.12),
                          child: Icon(
                            graded ? Icons.check : Icons.hourglass_empty,
                            color: graded ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        title: Text(attempt.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('MMM d, hh:mm a').format(attempt.submission.submittedAt.toDate())),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (graded)
                              Text(
                                '${attempt.submission.marksObtained}/${attempt.totalMarks}',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                              ),
                            const Icon(Icons.chevron_right, color: AppColors.ink300),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(int submitted, int graded) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.courseCode,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.assignment.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink900),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statColumn('Total\nStudents', '${widget.totalStudents}'),
              ),
              Expanded(
                child: _statColumn('Submitted', '$submitted', color: AppColors.primaryDark),
              ),
              Expanded(
                child: _statColumn('Graded', '$graded', color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, {Color color = AppColors.ink900}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.ink500,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
