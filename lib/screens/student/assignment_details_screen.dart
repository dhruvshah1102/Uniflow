import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../models/assignment.dart';
import '../../models/submission_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/student_dashboard_service.dart';
import '../../widgets/common/loading_skeleton_page.dart';

class AssignmentDetailsScreen extends StatefulWidget {
  final AssignmentModel assignment;
  final String courseCode;

  const AssignmentDetailsScreen({
    super.key,
    required this.assignment,
    required this.courseCode,
  });

  @override
  State<AssignmentDetailsScreen> createState() => _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> {
  final StudentDashboardService _service = StudentDashboardService.instance;
  bool _isLoading = true;
  bool _isUploading = false;
  SubmissionModel? _submission;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.uidFirebase;
      if (uid == null) throw Exception('Not authenticated');

      final submission = await _service.fetchAssignmentSubmissionForStudent(
        assignmentId: widget.assignment.assignmentId,
        studentId: uid,
      );

      setState(() {
        _submission = submission;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadSubmission() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('Could not read file data. Try picking another file.');
      }

      setState(() {
        _isUploading = true;
        _error = null;
      });

      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.uidFirebase;
      if (uid == null) throw Exception('Not authenticated');

      await _service.submitAssignment(
        assignmentId: widget.assignment.assignmentId,
        studentId: uid,
        courseId: widget.assignment.courseId,
        fileName: file.name,
        fileBytes: file.bytes!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment submitted successfully!')),
      );

      await _loadSubmission();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _openFile(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = widget.assignment.dueDate.toDate().isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      appBar: AppBar(
        title: const Text('Assignment Details'),
        backgroundColor: AppColors.surfaceWarm,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const LoadingSkeletonPage(cardCount: 2, showHeader: false)
          : RefreshIndicator(
              onRefresh: _loadSubmission,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _submission != null
                                    ? Colors.green.withOpacity(0.1)
                                    : (isOverdue ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _submission != null
                                    ? 'SUBMITTED'
                                    : (isOverdue ? 'MISSING' : 'PENDING'),
                                style: TextStyle(
                                  color: _submission != null
                                      ? Colors.green[800]
                                      : (isOverdue ? Colors.red[800] : Colors.orange[800]),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.assignment.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 16, color: AppColors.ink500),
                            const SizedBox(width: 6),
                            Text(
                              'Due: ${DateFormat('MMM d, h:mm a').format(widget.assignment.dueDate.toDate())}',
                              style: TextStyle(
                                color: isOverdue && _submission == null ? Colors.red : AppColors.ink500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 16),
                        const Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.assignment.description,
                          style: const TextStyle(color: AppColors.ink700, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                    ),

                  const Text(
                    'Your Work',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_submission == null) ...[
                    if (!isOverdue)
                      InkWell(
                        onTap: _isUploading ? null : _uploadSubmission,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primaryDark, width: 2, style: BorderStyle.solid),
                          ),
                          child: Center(
                            child: _isUploading
                                ? const CircularProgressIndicator()
                                : const Column(
                                    children: [
                                      Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primaryDark),
                                      SizedBox(height: 12),
                                      Text(
                                        'Tap to Upload File',
                                        style: TextStyle(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'PDF, DOC, JPG, PNG allowed',
                                        style: TextStyle(color: AppColors.ink500, fontSize: 12),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Deadline has passed. Cannot submit anymore.',
                            style: TextStyle(color: AppColors.ink500),
                          ),
                        ),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text(
                                'Successfully turned in',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink900,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('MMM d, h:mm a').format(_submission!.submittedAt.toDate()),
                                style: const TextStyle(color: AppColors.ink500, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.ink100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.attach_file, color: AppColors.ink700),
                            ),
                            title: const Text('Uploaded File', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Tap to view'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openFile(_submission!.fileUrl),
                          ),
                          if (_submission!.marksObtained != null) ...[
                             const Divider(),
                             Padding(
                               padding: const EdgeInsets.symmetric(vertical: 8.0),
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   const Text(
                                     'Grade',
                                     style: TextStyle(
                                       fontSize: 16,
                                       fontWeight: FontWeight.bold,
                                     ),
                                   ),
                                   Text(
                                     '${_submission!.marksObtained}',
                                     style: const TextStyle(
                                       fontSize: 18,
                                       fontWeight: FontWeight.w900,
                                       color: AppColors.primaryDark,
                                     ),
                                   )
                                 ],
                               ),
                             )
                          ]
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
