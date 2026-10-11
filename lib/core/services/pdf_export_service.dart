import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mcq_test_app/models/question.dart';
import 'package:mcq_test_app/models/test.dart';

class PdfExportService {
  static Future<String?> generateAndSaveSolutionPdf({
    required Test test,
    required List<Question> questions,
    required Map<String, String> selectedAnswers,
    required int score,
    required int total,
    required String studentName,
    required String rollNumber,
    DateTime? submissionDate,
  }) async {
    final subDate = submissionDate ?? DateTime.now();
    final percentage = total > 0 ? ((score / total) * 100).toStringAsFixed(1) : '0';

    // 1. Create a new PDF document
    final document = PdfDocument();
    document.pageSettings.margins.all = 36; // 0.5 inch margins

    // Palette
    final primaryColor = PdfColor(99, 102, 241);     // #6366F1 Indigo
    final textDark = PdfColor(15, 23, 42);          // #0F172A Slate 900
    final textSecondary = PdfColor(71, 85, 105);    // #475569 Slate 600
    final correctColor = PdfColor(16, 185, 129);    // #10B981 Emerald
    final incorrectColor = PdfColor(239, 68, 68);   // #EF4444 Red
    final unansweredColor = PdfColor(245, 158, 11); // #F59E0B Amber
    final borderColor = PdfColor(226, 232, 240);    // #E2E8F0

    // Fonts
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5);
    final boldFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    // Footer template with page numbering
    final footer = PdfPageTemplateElement(const Rect.fromLTWH(0, 0, 540, 20));
    footer.graphics.drawString(
      'MCQ Pro — Smart Tests. Strong Outcomes.  •  Confidential Student Report',
      smallFont,
      brush: PdfSolidBrush(textSecondary),
      bounds: const Rect.fromLTWH(0, 0, 540, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    document.template.bottom = footer;

    // Add first page
    var page = document.pages.add();
    var graphics = page.graphics;
    double y = 10;

    // Header banner
    graphics.drawString(
      'MCQ PRO',
      titleFont,
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 24),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 24;

    graphics.drawString(
      'Test Assessment & Detailed Solutions Report',
      subtitleFont,
      brush: PdfSolidBrush(textDark),
      bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 22;

    // Draw horizontal separator
    graphics.drawLine(
      PdfPen(borderColor, width: 1),
      Offset(0, y),
      Offset(page.getClientSize().width, y),
    );
    y += 10;

    // Metadata Grid (Test & Student info)
    final grid = PdfGrid();
    grid.columns.add(count: 2);
    grid.columns[0].width = page.getClientSize().width / 2;
    grid.columns[1].width = page.getClientSize().width / 2;

    final row1 = grid.rows.add();
    row1.cells[0].value = 'Student Name: $studentName';
    row1.cells[1].value = 'Roll Number: $rollNumber';

    final row2 = grid.rows.add();
    row2.cells[0].value = 'Class & Division: Std ${test.studentClass} - ${test.division ?? "All"}';
    row2.cells[1].value = 'Medium: ${test.medium.toUpperCase()}';

    final row3 = grid.rows.add();
    row3.cells[0].value = 'Subject: ${test.subject}';
    row3.cells[1].value = 'Topic: ${test.topic}';

    final row4 = grid.rows.add();
    row4.cells[0].value = 'Test Code: ${test.testCode ?? "N/A"}';
    row4.cells[1].value = 'Submission Date: ${DateFormat.yMMMd().add_jm().format(subDate)}';

    final row5 = grid.rows.add();
    row5.cells[0].value = 'Score Obtained: $score / $total ($percentage%)';
    row5.cells[1].value = 'Performance: ${score >= (total * 0.5) ? "PASSED" : "NEEDS PRACTICE"}';

    grid.style.cellPadding = PdfPaddings(left: 6, top: 4, right: 6, bottom: 4);
    grid.style.font = bodyFont;

    final result = grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 0),
    );
    if (result != null) {
      y = result.bounds.bottom + 16;
      graphics = result.page.graphics;
      page = result.page;
    } else {
      y += 80;
    }

    graphics.drawString(
      'QUESTIONS, SELECTED ANSWERS & SOLUTIONS',
      subtitleFont,
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18),
    );
    y += 20;

    // Iterate through questions
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final userAns = selectedAnswers[q.id];
      final isCorrect = userAns == q.correctAnswer;
      final isUnanswered = userAns == null || userAns.isEmpty;

      // Check if we need a new page (rough height estimate ~120 units)
      if (y > page.getClientSize().height - 120) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 10;
      }

      // Status Tag & Question Title
      String statusText = isCorrect ? '[CORRECT]' : (isUnanswered ? '[UNANSWERED]' : '[INCORRECT]');
      PdfColor statusColor = isCorrect ? correctColor : (isUnanswered ? unansweredColor : incorrectColor);

      graphics.drawString(
        'Q${i + 1}. ${q.questionText}',
        boldFont,
        brush: PdfSolidBrush(textDark),
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width - 90, 30),
      );

      graphics.drawString(
        statusText,
        boldFont,
        brush: PdfSolidBrush(statusColor),
        bounds: Rect.fromLTWH(page.getClientSize().width - 85, y, 85, 16),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      y += 28;

      // Options
      graphics.drawString('   A) ${q.optionA}', bodyFont, brush: PdfSolidBrush(textSecondary), bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 14));
      y += 14;
      graphics.drawString('   B) ${q.optionB}', bodyFont, brush: PdfSolidBrush(textSecondary), bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 14));
      y += 14;
      graphics.drawString('   C) ${q.optionC}', bodyFont, brush: PdfSolidBrush(textSecondary), bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 14));
      y += 14;
      graphics.drawString('   D) ${q.optionD}', bodyFont, brush: PdfSolidBrush(textSecondary), bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 14));
      y += 16;

      // Answers summary line
      final ansSummary = '   Your Selection: ${userAns ?? "None (Unanswered)"}   |   Correct Answer: Option ${q.correctAnswer}';
      graphics.drawString(
        ansSummary,
        boldFont,
        brush: PdfSolidBrush(statusColor),
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 14),
      );
      y += 15;

      // Explanation
      if (q.explanation.isNotEmpty) {
        graphics.drawString(
          '   Explanation: ${q.explanation}',
          bodyFont,
          brush: PdfSolidBrush(textSecondary),
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 24),
        );
        y += 20;
      }

      // Divider line between questions
      graphics.drawLine(
        PdfPen(borderColor, width: 0.5),
        Offset(0, y),
        Offset(page.getClientSize().width, y),
      );
      y += 12;
    }

    // 2. Save document to bytes
    final List<int> bytes = document.saveSync();
    document.dispose();

    // 3. Save or download file across platforms
    final filename = 'MCQPro_Solution_${test.testCode ?? "TEST"}_Roll_${rollNumber.replaceAll(" ", "_")}.pdf';

    try {
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Test Solutions PDF',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: Uint8List.fromList(bytes),
      );
      return output ?? filename;
    } catch (e) {
      debugPrint('Error saving file: $e');
      return null;
    }
  }

  /// Exports an official Teacher Question Paper with Answer Key & Explanations
  static Future<String?> generateAndSaveTestPaperPdf({
    required Test test,
    required List<Question> questions,
    bool includeAnswerKey = true,
  }) async {
    final document = PdfDocument();
    document.pageSettings.margins.all = 36;

    final primaryColor = PdfColor(99, 102, 241);
    final textDark = PdfColor(15, 23, 42);
    final textSecondary = PdfColor(71, 85, 105);
    final correctColor = PdfColor(16, 185, 129);
    final borderColor = PdfColor(226, 232, 240);

    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5);
    final boldFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    final footer = PdfPageTemplateElement(const Rect.fromLTWH(0, 0, 540, 20));
    footer.graphics.drawString(
      'MCQ Pro — Master Test Archive  •  Standard ${test.studentClass} ${test.medium.toUpperCase()}',
      smallFont,
      brush: PdfSolidBrush(textSecondary),
      bounds: const Rect.fromLTWH(0, 0, 540, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    document.template.bottom = footer;

    var page = document.pages.add();
    var graphics = page.graphics;
    double y = 10;

    graphics.drawString(
      'MCQ PRO — TEST QUESTION PAPER',
      titleFont,
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 24),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 24;

    graphics.drawString(
      'Subject: ${test.subject}  |  Topic: ${test.topic}',
      subtitleFont,
      brush: PdfSolidBrush(textDark),
      bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 22;

    graphics.drawLine(
      PdfPen(borderColor, width: 1),
      Offset(0, y),
      Offset(page.getClientSize().width, y),
    );
    y += 10;

    final grid = PdfGrid();
    grid.columns.add(count: 2);
    grid.columns[0].width = page.getClientSize().width / 2;
    grid.columns[1].width = page.getClientSize().width / 2;

    final row1 = grid.rows.add();
    row1.cells[0].value = 'Class: Standard ${test.studentClass} (${test.division ?? "All"})';
    row1.cells[1].value = 'Medium: ${test.medium.toUpperCase()}';

    final row2 = grid.rows.add();
    row2.cells[0].value = 'Total Questions: ${questions.length}';
    row2.cells[1].value = 'Duration: ${test.duration} Minutes';

    final row3 = grid.rows.add();
    row3.cells[0].value = 'Test Code: ${test.testCode ?? "N/A"}';
    row3.cells[1].value = 'Date: ${DateFormat("dd MMM yyyy").format(test.createdAt ?? DateTime.now())}';

    grid.style.cellPadding = PdfPaddings(left: 6, top: 4, right: 6, bottom: 4);
    grid.draw(page: page, bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 0));
    y += 75;

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (y > page.getClientSize().height - 120) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 20;
      }

      graphics.drawString(
        'Q${i + 1}. ${q.questionText}',
        boldFont,
        brush: PdfSolidBrush(textDark),
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 30),
      );
      y += 22;

      for (int optIdx = 0; optIdx < q.options.length; optIdx++) {
        final optLabel = ['A', 'B', 'C', 'D'][optIdx];
        final optText = q.options[optIdx];
        final isCorrect = includeAnswerKey && optText == q.correctAnswer;

        final brush = isCorrect ? PdfSolidBrush(correctColor) : PdfSolidBrush(textSecondary);
        final font = isCorrect ? boldFont : bodyFont;

        graphics.drawString(
          '  ($optLabel) $optText ${isCorrect ? " ✓ [CORRECT]" : ""}',
          font,
          brush: brush,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 16),
        );
        y += 16;
      }

      if (includeAnswerKey && q.explanation.isNotEmpty) {
        y += 4;
        graphics.drawString(
          '  Explanation: ${q.explanation}',
          bodyFont,
          brush: PdfSolidBrush(textSecondary),
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 24),
        );
        y += 18;
      }

      graphics.drawLine(
        PdfPen(borderColor, width: 0.5),
        Offset(0, y),
        Offset(page.getClientSize().width, y),
      );
      y += 12;
    }

    final List<int> bytes = document.saveSync();
    document.dispose();

    final filename = 'MCQPro_Test_${test.testCode ?? "TEST"}_Std${test.studentClass}.pdf';

    try {
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Test Question Paper PDF',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: Uint8List.fromList(bytes),
      );
      return output ?? filename;
    } catch (e) {
      debugPrint('Error saving file: $e');
      return null;
    }
  }
}
