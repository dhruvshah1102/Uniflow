import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/academic_result.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';

class PdfHelper {
  static Future<void> generateTranscriptPdf({
    required StudentModel student,
    required UserModel user,
    required StudentAcademicRecord record,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(user, student, record),
          pw.SizedBox(height: 20),
          ..._buildSemesters(record),
          pw.Divider(),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildHeader(UserModel user, StudentModel student, StudentAcademicRecord record) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('UNIFLOW DIGITAL CAMPUS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
        pw.SizedBox(height: 10),
        pw.Text('Official Academic Transcript', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Name: ${user.name}', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Enrollment No: ${student.enrollmentNo}', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Program: B.Tech', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#1E3A8A'), width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                children: [
                  pw.Text('CGPA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(record.cgpa.toStringAsFixed(2), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
                ]
              )
            )
          ]
        ),
      ]
    );
  }

  static List<pw.Widget> _buildSemesters(StudentAcademicRecord record) {
    final widgets = <pw.Widget>[];

    for (final sem in record.transcript) {
      widgets.add(_buildSemesterTable(sem.semester, sem.sgpa, sem.results));
      widgets.add(pw.SizedBox(height: 20));
    }

    if (record.currentSemesterResults.isNotEmpty) {
      widgets.add(_buildSemesterTable(
        record.currentSemesterResults.first.semester,
        calculateSgpa(record.currentSemesterResults),
        record.currentSemesterResults,
        isCurrent: true,
      ));
    }

    return widgets;
  }

  static pw.Widget _buildSemesterTable(int semester, double sgpa, List<AcademicResultItem> results, {bool isCurrent = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Semester $semester ${isCurrent ? "(Current)" : ""}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Course Code', 'Course Name', 'Credits', 'Grade'],
          data: results.map((e) => [e.courseCode, e.courseName.isNotEmpty ? e.courseName : e.courseCode, e.credits.toString(), e.grade]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 5),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('SGPA: ${sgpa.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
      ]
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 20),
        pw.Text('This is a computer-generated document. No signature is required.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        pw.Text('Date Generated: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
      ]
    );
  }
}
