import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/academic_result.dart';
import '../../providers/auth_provider.dart';
import '../../services/academic_results_service.dart';
import '../../services/transcript_service.dart';
import '../../services/pdf_helper.dart';
import '../../widgets/common/loading_skeleton_page.dart';

class StudentGradesScreen extends StatelessWidget {
  const StudentGradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final student = auth.studentProfile;

    if (auth.isLoading) {
      return const LoadingSkeletonPage(cardCount: 3);
    }

    if (auth.currentUser == null || student == null) {
      return const Center(child: Text('Student profile not available.'));
    }

    return StreamBuilder<StudentAcademicRecord>(
      stream: TranscriptService.instance.watchComprehensiveTranscript(
        studentId: student.userId,
        currentSemester: student.semester,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingSkeletonPage(cardCount: 4);
        }

        if (snapshot.hasError) {
          return _EmptyState(
            title: 'Unable to load grades',
            subtitle: snapshot.error.toString(),
            icon: Icons.error_outline,
          );
        }

        final record = snapshot.data;
        if (record == null) {
          return const _EmptyState(
            title: 'No academic results yet',
            subtitle: 'Grades will appear here once faculty uploads marks.',
            icon: Icons.grade_outlined,
          );
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SummaryHeader(
                  title: 'Grades & Transcript',
                  subtitle: 'Course-wise grades, SGPA, and your full academic record.',
                  cgpa: record.cgpa,
                  sgpa: calculateSgpa(record.currentSemesterResults),
                  completedCredits: record.completedCredits,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  labelColor: AppColors.primaryDark,
                  unselectedLabelColor: AppColors.ink500,
                  indicatorColor: AppColors.primaryDark,
                  tabs: [
                    Tab(text: 'Grades'),
                    Tab(text: 'Transcript'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _GradesView(record: record),
                    _TranscriptView(record: record),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradesView extends StatelessWidget {
  final StudentAcademicRecord record;

  const _GradesView({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final current = record.currentSemesterResults;
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SizedBox(height: 16),
          if (current.isEmpty)
            const _EmptyState(
              title: 'No grades published yet',
              subtitle: 'Once faculty uploads results for this semester, they will appear here instantly.',
              icon: Icons.school_outlined,
            )
          else
            ...current.map((result) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ResultCard(result: result),
                )),
        ],
      ),
    );
  }
}

class _TranscriptView extends StatelessWidget {
  final StudentAcademicRecord record;

  const _TranscriptView({required this.record});

  @override
  Widget build(BuildContext context) {
    final hasCurrentSemesterResults = record.currentSemesterResults.isNotEmpty;
    final transcriptScoreLabel = hasCurrentSemesterResults ? 'SGPA' : 'Prev Sem CGPA';
    final transcriptScoreValue = hasCurrentSemesterResults
        ? (record.transcript.isEmpty ? 0.0 : record.transcript.last.sgpa)
        : (record.transcript.isEmpty ? 0.0 : record.transcript.last.sgpa);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SummaryHeader(
          title: 'Academic Transcript',
          subtitle: 'Expandable semester history with SGPA and overall CGPA.',
          cgpa: record.cgpa,
          sgpa: transcriptScoreValue,
          sgpaLabel: transcriptScoreLabel,
          completedCredits: record.completedCredits,
        ),
        const SizedBox(height: 16),
        if (!hasCurrentSemesterResults)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _EmptyState(
              title: 'Current semester not published yet',
              subtitle: 'Showing the latest available academic record from previous semesters.',
              icon: Icons.schedule_outlined,
            ),
          ),
        if (record.transcript.isEmpty)
          const _EmptyState(
            title: 'No transcript data yet',
            subtitle: 'Transcript will appear as semester results are published.',
            icon: Icons.receipt_long_outlined,
          )
        else
          ...record.transcript.map(
            (semester) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SemesterCard(summary: semester),
            ),
          ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final user = auth.currentUser;
              final student = auth.studentProfile;
              if (user != null && student != null) {
                 await PdfHelper.generateTranscriptPdf(
                   student: student,
                   user: user,
                   record: record,
                 );
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transcript downloaded/opened.')),
                 );
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Transcript'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double cgpa;
  final double sgpa;
  final String sgpaLabel;
  final int completedCredits;

  const _SummaryHeader({
    required this.title,
    required this.subtitle,
    required this.cgpa,
    required this.sgpa,
    this.sgpaLabel = 'SGPA',
    required this.completedCredits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatBubble(label: 'CGPA', value: cgpa.toStringAsFixed(2))),
              const SizedBox(width: 10),
              Expanded(child: _StatBubble(label: sgpaLabel, value: sgpa.toStringAsFixed(2))),
              const SizedBox(width: 10),
              Expanded(child: _StatBubble(label: 'Credits', value: '$completedCredits')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String label;
  final String value;

  const _StatBubble({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final AcademicResultItem result;

  const _ResultCard({required this.result});

  Color get _gradeColor {
    return switch (result.grade.toUpperCase()) {
      'AA' || 'AB' || 'O' || 'A+' => AppColors.success,
      'BB' || 'BC' || 'A' || 'B+' => AppColors.warning,
      'CC' || 'CD' || 'DD' || 'B' || 'C' => AppColors.info,
      _ => AppColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _gradeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              result.grade,
              style: TextStyle(
                color: _gradeColor,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.courseName.isNotEmpty ? result.courseName : result.courseCode,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.courseCode} | Semester ${result.semester}',
                  style: const TextStyle(color: AppColors.ink500, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'Marks: ${result.marks} / 100',
                  style: const TextStyle(color: AppColors.ink700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${result.credits} cr',
            style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  final SemesterAcademicSummary summary;

  const _SemesterCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          'Semester ${summary.semester}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900),
        ),
        subtitle: Text(
          'SGPA ${summary.sgpa.toStringAsFixed(2)}',
          style: const TextStyle(color: AppColors.ink500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            summary.sgpa.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
          ),
        ),
        children: [
          if (summary.results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('No results in this semester yet.'),
            )
          else
            ...summary.results.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ResultCard(result: result),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.primaryDark),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.ink500, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
